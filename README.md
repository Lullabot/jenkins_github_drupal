![jenktocat](https://api.monosnap.com/image/download?id=9PMKonRKS2i1el0vJZ7cuK1oQ)

## Overview
Do you build Drupal sites? Do you use GitHub to manage your code for these projects? 
Do you use Jenkins to automate continuous integration? Well you should do all of these things! 
And if you do, then you should also use Lullabot's Magical Jenkins/Github/Drupal Scripts™.

These scripts will build your repository's branches so that you can test them in a full
Drupal environment. No more local checkout of a branch, running updates, and synchronizing
your database and files in order to test a branch. Just install the scripts and let the 
machine do it for you automatically every time you create a new pull request.

Brought to you by your friends at Lullabot!

If you'd like to read more, check out 
[this article on Lullabot.com](http://www.lullabot.com/blog/article/github-pull-request-builder-drupal).

## Installation
Please see INSTALL.md

## Usage
This script should be executed within Jenkins, and will fail otherwise.

First, call the directory preparer, which moves the pull request to your
webroot, and merges it into master.

`prepare_dir.sh` `[-himvx]` `<webroot>`

Then, call the site cloning script, which uses drush to clone an existing
staging site.

`clone_site.sh` `[-deghHilvxc]` `<source-drush-alias>` `<url>`

To clean up afterwards, call cleanup.sh using the same pull request ID and
location of your webroot.

`cleanup.sh` `[-dhiluvxc]`

## What does it do?
- Moves the checked out repository to a unique directory in the workspace.
- Creates a symlink to the docroot of the drupal directory in the webroot.
- Creates a new branch from the pull request and merges that branch to
  master.
- Copies the settings.php from an existing site to this new drupal site.
- Clones the database from the source site, prefixing any tables with a
  unique identifier to this pull request.
- Rsyncs the files directory from the source site.

## Requirements
- Drush
- A web accessible URL for the pull request. The location of the docroot for
  this URL should be specified with the -l option.
- An existing Drupal 7 site with a site alias, and empty prefix line in the
  database array in settings.php
- A Jenkins job that checks out the Pull Request to 'new_pull_request' directory
  inside the job workspace.

## Arguments
`<webroot>`

  Location of the parent directory of the web root this site will be hosted at.
  Defaults to the job workspace. Note, the Jenkins user must have write
  permissions to this directory.

`<source-drush-alias>`

  The drush alias to the site whose database and files will be cloned to build
  the pull request test environment.

`<url>`

  The parent URL that the destination site will be visible at. Defaults to
  'http://default'. The domain name the site will be set up at. Note, the site
  will be in a subdirectory of this domain using the Pull Request ID, so if the
  Pull Request ID is 234, and you pass https://www.example.com/foo, the site
  will be at https://www.example.com/foo/234.

## Options
* `-c`  Optional. Specifies that the full database is cloned instead of using
        table prefixes.
* `-e`  Optional. Extra settings to be concatenated to the settings.php file
        when it is cloned. Only used in clone_site.sh.
* `-g`  Optional. The http server's group, such as www-data or apache. This is
        only used in clone_site.sh to ensure that the file permissions are set
        properly on the Drupal file directory.
* `-h`  Show this message
* `-H`  The directory to pass to --link-dir during rsync. This is only used in
        clone_site.sh to use a shared files directory to create hardlinks from.
        This is useful for sites that have large file directories, to avoid
        eating up disk space. It is recommended to keep this directory synced
        regularly with the stage files dir. See `man rsync` for more details.
* `-i`  The Github pull request issue number.
* `-l`  The location of the parent directory of the web root. Same as
        `<webroot>`.
* `-m`  The branch the pull request should be merged to. Defaults to 'master'.
        This is only used with prepare_dir.sh.
* `-d`  The path to drush. Defaults to drush.
* `-u`  Optional. URIs of the sites to clean up when running cleanup.sh. Useful
        when there are symlinks in /sites.
* `-v`  Verbose mode, passed to all drush commands.
* `-x`  Turn on bash xtrace and drush debug mode.
