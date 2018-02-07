#!/bin/sh
# Jenkins Wordpress Push Script
# Star Dot Hosting Inc, 2017

#check command input
if [ -z "$1" ];
then
        echo "JENKINS WP PUSH"
        echo "---------------"
        echo ""
        echo "Usage : ./jenkins-wordpress.sh sitename.com"
        echo ""
        exit 0
fi

# Declare variables
currentdate=`date "+%Y-%m-%d"`
scriptpath="/usr/local/bin/jenkins"
# Command arguments
site_name=`echo "$1" |  awk -F "." '{printf "%s\n" ,$1}' | sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/' | sed 's/-/_/g' | awk -F. '{str="";if ( length($1) > 16 ) str="";print substr($1,0,15)str""$2}'`

# Get configuration variables
source ${scriptpath}/config/wordpress/${site_name}.conf


# Enable/disable maiintenance mode
#enable_maint="sed -i '/MAINTENANCE MODE BEGIN/,/MAINTENANCE MODE END/{/MAINTENANCE MODE BEGIN/n;/MAINTENANCE MODE END/!{s/^#//g}}' $destination_dir/.htaccess"
#disable_maint="sed -i '/MAINTENANCE MODE BEGIN/,/MAINTENANCE MODE END/{/MAINTENANCE MODE BEGIN/n;/MAINTENANCE MODE END/!{s/^/#/g}}' $destination_dir/.htaccess"

# Enable Maintenance Mode
echo "Enabling maintenance mode.."
ssh -l $destination_user $destination_host \
    "cd $destination_dir;\
    mv maintenance_off.html maintenance_on.html"

# Transfer Files
echo "Transferring files from staging to production.."
ssh -l $staging_user $staging_host \
    "cd $source_dir;\
    /usr/bin/rsync -rlptDu --exclude='wp-config.php' --exclude='.htaccess' --exclude='shift8-jenkins' --exclude='maintenance_on.html' --exclude='maintenance_off.html' --delete ${source_dir}/ ${destination_user}@${destination_host}:${destination_dir}"

# Transfer Database to temp file
echo "Dumping staging database to temp file.."
ssh -l $staging_user $staging_host bash -c "'
/usr/bin/mysqldump -u $staging_db_user --password=\"$staging_db_password\" -h $staging_db_host $staging_db_name
'" > ${scriptpath}/sqltmp/sqltmp.sql

# Transfer Database to production
echo "Transferring staging database to production.."
cat ${scriptpath}/sqltmp/sqltmp.sql | ssh -l $destination_user $destination_host bash -c "'
/usr/bin/mysql -u $prod_db_user --password=\"$prod_db_password\" -h $prod_db_host $prod_db_name'"

# Get Prod Site Url
echo "Fixing URLs on production.."
destination_siteurl=$(ssh -l $destination_user $destination_host "cd $destination_dir;wp option get siteurl --allow-root")
staging_siteurl=$(ssh -l $staging_user $staging_host "cd $source_dir;wp option get siteurl --allow-root")

ssh -l $destination_user $destination_host \
    "cd $destination_dir;\
    wp search-replace \"$staging_siteurl\" \"$destination_siteurl\" --allow-root --all-tables --precise;\
    wp plugin deactivate shift8-jenkins --allow-root;\
    wp cache flush --allow-root"

# Disable Maintenance Mode
echo "Disabling maintenance mode.."
ssh -l $destination_user $destination_host \
    "cd $destination_dir;\
    mv maintenance_on.html maintenance_off.html"
