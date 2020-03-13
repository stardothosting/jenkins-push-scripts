#!/bin/sh

#check command input
if [ "$#" -ne 2 ];
then
        echo "JENKINS DRUPAL 8 PUSH"
        echo "---------------------"
        echo ""
        echo "Usage : ./jenkins-d8.sh project-name branch-name"
        echo ""
        exit 1
fi

# Declare variables
currentdate=`date "+%Y-%m-%d"`
scriptpath="/usr/local/bin/jenkins"
destination_project="$1"
destination_branch=`echo "$2" | awk -F "/" '{printf "%s", $2}'`

# Get configuration variables
source ${scriptpath}/config/drupal8/${destination_project}.conf
echo "Pushing to $destination_branch .. "

# Declare functions
alert_notification() {
    echo "Push script failure : $2" | mail -s "$destination_project : Push script Failure" $1
}

sanity_check() {
    if [ $1 -ne 0 ]
    then
        echo "$2"
        alert_notification $alert_email "$2"
        exit 1
    fi
}

################
# STAGING PUSH #
################
if [ "$destination_branch" == "staging" ]
then
    destination_user="$dest_user_staging"
    destination_host="$dest_host_staging"
    destination_dir="$dest_dir_staging"

    # Push command over ssh
    ssh -l $destination_user $destination_host \
        "cd $destination_dir;\
        rm -rf composer.lock;\
        git reset --hard;\
        git fetch --all;\
        git checkout -f $destination_branch;\
        git reset --hard;\
        git fetch --all;\
        git pull origin $destination_branch;\
        /usr/local/bin/composer install --no-interaction --prefer-dist --optimize-autoloader;\
        /usr/local/bin/composer dump-autoload -o;\
        ${destination_dir}/vendor/bin/drush cache-rebuild"

    # Get test results
    if [ "$staging_tests" == "TRUE" ]
    then
        ssh -l $destination_user $destination_host \
            "cat ${destination_dir}/tests/results/${destination_project}_test1.xml" > ${item_rootdir}/tests/results/${destination_project}_test1.xml
    fi

###################
# PRODUCTION PUSH #
###################
elif [ "$destination_branch" == "production" ]
then
    destination_user="$dest_user_prod"
    destination_host="$dest_host_prod"
    destination_dir="$dest_dir_prod"
    pre_prod_dir="$pre_prod"

    # Get current latest commit running on prod
    ssh -l $destination_user $destination_host "cd $destination_dir;git fetch --all"
    current_local_commit=`ssh -l $destination_user $destination_host "cd $destination_dir;git rev-parse --short HEAD"`
    current_remote_commit=`ssh -l $destination_user $destination_host "cd $destination_dir;git rev-parse --short origin/${destination_branch} "`

    # Make sure local and remote arent the same because then theres no reason to push
    if [ "$current_local_commit" == "$current_remote_commit" ]
    then
        alert_msg="Remote HEAD : $current_remote_commit matches Local HEAD : $current_local_commit, exiting..."
        echo "$alert_msg"
        alert_notification $alert_email "$alert_msg"
        exit 1
    fi

    echo "Commit currently running on production : $current_local_commit"
    echo "Commit currently on remote : $current_remote_commit"

    # Prep the pre prod folder
    check_clear_folder=`ssh -l $destination_user $destination_host "rm -rf $pre_prod_dir"`
    sanity_check $? "Error with cleaning pre prod folder : $check_clear_folder"

    # Clone files from the repo in prod prep folder, set permissions and rsync files from live site
    ssh -l $destination_user $destination_host \
        "mkdir $pre_prod_dir &&\
        cd $pre_prod_dir &&\
        git clone $git_repo . &&\
        git checkout -f $destination_branch &&\
        rsync --ignore-existing -razp --progress --exclude '.git' --exclude 'vendor' --exclude '.cache' ${destination_dir}/ ${pre_prod_dir} &&\
        chown -R ${user_perm}:${group_perm} ${pre_prod_dir} &&\
        chmod 755 ${pre_prod_dir}"

    # Sanity checks
    echo "Doing composer install ..."
    check_composer_install=`ssh -l $destination_user $destination_host "cd $pre_prod_dir;/usr/local/bin/composer install --no-interaction --prefer-dist --optimize-autoloader"`
    sanity_check $? "Error with composer install on production : $check_composer_install"

    echo "Doing composer update ..."
    check_composer_update=`ssh -l $destination_user $destination_host "cd $pre_prod_dir;/usr/local/bin/composer update"`
    sanity_check $? "Error with composer update on production : $check_composer_install"

    echo "Making the destination folder ..."
    # Mkdir the folder to production
    check_mkdir=`ssh -l $destination_user $destination_host "mkdir ${destination_dir}_${current_remote_commit}"`
    sanity_check $? "Error with making directory to cluster folder : $check_mkdir"

    echo "Rsyncing pre prod folder to new destination folder ..."
    # Rsync preprod to prod folder
    check_rsync=`ssh -l $destination_user $destination_host "rsync -ravzp --exclude '.ssh' ${pre_prod_dir}/ ${destination_dir}_${current_remote_commit}"`
    sanity_check $? "Error with rsyncing pre-prod folder to cluster folder : $check_rsync"

    echo "Sanitizing permissions ..."
    # Sanitize permissions one last time
    ssh -l $destination_user $destination_host \
       "cd ${dest_dir_root};\
       chown -R ${user_perm}:${group_perm} ${destination_project}_${current_remote_commit};\
       chmod 755 ${destination_project}_${current_remote_commit}"

    echo "Changing symlink to point to new folder ..."
    # Change the symlink to point to new folder
    check_force_symlink=`ssh -l $destination_user $destination_host "cd $dest_dir_root;ln -sfn ${destination_project}_${current_remote_commit} ${destination_project}"`
    sanity_check $? "Error with creating symlink to newly pushed folder : $check_force_symlink"
    echo "Check force symlink : $check_force_symlink"

    # Run updatedb
    #check_updatedb=`ssh -l $destination_user $destination_host "cd ${destination_dir}_${current_remote_commit} && drush updb -y"`
    #sanity_check $? "Error with updatedb on production : $check_updatedb"

    echo "Removing all folders in var www except current and previous commit ..."
    # Remove all folders except the current and previous commit folders as well as the symlink
    ssh -l $destination_user $destination_host \
        "cd ${dest_dir_root};\
        find . -maxdepth 1 \! \( -name ${destination_project} -o -name ${destination_project}_${current_remote_commit} -o -name ${destination_project}_${current_local_commit} -o -name .ssh -o -name reloadvcl.sh -o -name html \) -exec rm -rf '{}' \;"

    echo "Clearing cache locally ..."
    # Clear cache locally
    check_cache=`ssh -l $destination_user $destination_host "cd ${destination_dir}_${current_remote_commit} && drush cache-rebuild && /bin/sh /var/www/reloadvcl.sh && /bin/redis-cli FLUSHALL"`
    sanity_check $? "Error with clearing cache locally : $check_cache"

    # Sync files & clear cache on other node servers
    for i in $(echo $node_servers | sed "s/,/\\n/g")
    do
        echo "doing $i .. "
        check_node_rsync=`ssh -l $destination_user $destination_host "/usr/bin/rsync -ravz --delete --exclude '.ssh' --exclude '/var/www/html' --progress /var/www/ root@$i:/var/www"`
        sanity_check $? "Error with rsyncing files to node server : $check_node_rsync"
    done
else
    echo "Invalid branch provided : $destination_branch"
    exit 1
fi
