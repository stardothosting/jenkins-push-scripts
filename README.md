# Jenkins Push Bash Scripts
Bash scripts to be used for continuous code integration with Jenkins and GitHub.

## Laravel
Included in this repository is a Laravel push bash script. Pushing a change to your code repository will trigger jenkins to execute this script. 

This script will propagate code changes from your local development environment to your staging or production environments. A full blog post detailing [How to set Jenkins up to automatically push your laravel code](https://www.shift8web.ca/2018/02/use-jenkins-git-automate-code-pushes-laravel-site/) can be read for further information.

## Wordpress
I have included a shell script for Jenkins to trigger when pushing code to your Wordpress development project. 

This script will not only propagate code from your staging (test) site, but will also copy the database over. Functions are also triggered to search and replace the staging url with the production url. During the push process, coordinated by this script, a maintenance message is put up for the entire duration of the push. This mitigates any issues with visibility. 

You can read a blog post that goes into further details for the [Jenkins Wordpress push script](https://www.shift8web.ca/2017/12/wordpress-plugin-to-integrate-jenkins-build-api/) for more details as far as how the script works.

## Drupal 8
I have included a shell script for pushing a Drupal 8 site via Jenkins. This script likely will need to be modified to suit your environment. The script is designed to accommodate synchronizing to multiple webservers for a production push. 

This script relies on git to pull code based on the branch pushed and is similar to how the Laravel push script is structured.

## About
We are a [Web Design Company in Toronto](https://www.shift8web.ca) that specializes in infrastructure management as well as design and development of Wordpress, Drupal, Laravel and Django projects.
