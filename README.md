# Jenkins Push Bash Scripts
Bash scripts to be used for continuous code integration with Jenkins and GitHub.

## Laravel
Included in this repository is a Laravel push bash script. Pushing a change to your code repository will trigger jenkins to execute this script. 

This script will propagate code changes from your local development environment to your staging or production environments. A full blog post detailing [How to set Jenkins up to automatically push your laravel code](https://www.shift8web.ca/2018/02/use-jenkins-git-automate-code-pushes-laravel-site/) can be read for further information.

## Wordpress
I have included a shell script for Jenkins to trigger when pushing code to your Wordpress development project. 

This script will not only propagate code from your staging (test) site, but will also copy the database over. Functions are also triggered to search and replace the staging url with the production url. During the push process, coordinated by this script, a maintenance message is put up for the entire duration of the push. This mitigates any issues with visibility. 

You can read a blog post that goes into further details for the [Jenkins Wordpress push script](https://www.shift8web.ca/2017/12/wordpress-plugin-to-integrate-jenkins-build-api/) for more details as far as how the script works.

## About
We are a [Web Design Company in Toronto](https://www.shift8web.ca) that specializes in infrastructure management as well as design and development of Wordpress, Drupal, Laravel and Django projects.
