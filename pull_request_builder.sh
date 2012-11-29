#!/usr/bin/env bash
set -e

usage()
{
cat << EOF
usage: $0 options

This script should be executed within Jenkins, and will fail otherwise.

WHAT DOES IT DO?
- Moves the checked out repository to a unique directory in the workspace

REQUIREMENTS:
- Drush
- A web accessible URL for the pull request. The location of the docroot for
  this URL should be specified with the -l option.
- An existing Drupal 7 site with a site alias, and empty prefix line in the
  database array in settings.php
- A Jenkins job that checks out the Pull Request to 'new_pull_request' directory
  inside the job workspace.

OPTIONS:
   -h      Show this message
   -l      Location of the docroot where the site will be symlinked to. Note,
           the Jenkins user must have write permissions to this directory.
   -d      Defaults to 'http://default'. The domain name the site will be set up
           at. Note, the site will be in a subdirectory of this domain using the
           Pull Request ID, so if the Pull Request ID is 234, and you pass
           https://www.example.com/foo, The site will be at
           https://www.example.com/foo/234.
   -a      The drush site alias for the source site to copy from.
   -r      The path to drush. Defaults to drush.
   -v      Verbose mode, passed to all drush commands.

EOF
}

DOCROOT=
DOMAIN="http://default"
ALIAS=
DRUSH="drush"
VERBOSE=""

while getopts “hl:d:a:r:v” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    l)
      DOCROOT=$OPTARG
      ;;
    d)
      DOMAIN=$OPTARG
      ;;
    a)
      ALIAS=$OPTARG
      ;;
    r)
      DRUSH=$OPTARG
      ;;
    v)
      VERBOSE="--verbose"
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

# If we're missing some of these variables, show the usage and throw an error.
if [[ -z $DOCROOT ]] || [[ -z $ALIAS ]]; then
  usage
  exit 1
fi

if [[ -z $sha1 ]] || [[ -z $WORKSPACE ]]; then
  echo "This script must be executed from within a proper Jenkins job."
  exit 1
fi

DRUSH="$DRUSH $VERBOSE"
# Pull out the Pull Request ID from the origin.
GHPRID=`echo $sha1 | grep -o '[0-9]'`
# This is the directory of the checked out pull request, from Jenkins.
ORIGINAL_DIR="${WORKSPACE}/new_pull_request"
# The directory where the checked out pull request will reside.
ACTUAL_DIR="${WORKSPACE}/${GHPRID}-actual"
# The command will attempt to merge master with the pull request.
BRANCH="pull-request-$GHPRID"

# Check to make sure drush is working.
$DRUSH $ALIAS status --quiet

SETTINGS="`$DRUSH $ALIAS dd`/`$DRUSH $ALIAS status site_path --pipe`/settings.php"
SETTINGS_DIR=`echo $DOMAIN |
# Remove http:// or https:// from the beginning.
sed -e "s/https\?:\/\///" |
# Replace all dots or slashes with underscores.
sed -e "s/[\.|\/]/_/g" |
# Remove trailing new lines.
tr -d '\n'`
NEW_SETTINGS="${DOCROOT}/sites/${SETTINGS_DIR}/settings.php"
PREFIX="pr_"
DB_PREFIX="${PREFIX}${GHPRID}_"
DB_NAME="`$DRUSH $ALIAS status database_name --pipe`"

# Remove the existing .git dir if it exists.
rm -rf $ACTUAL_DIR/.git
# Copy the new_pull_request directory.
rsync -a ${ORIGINAL_DIR}/ $ACTUAL_DIR
# Now remove the new_pull_request directory.
rm -rf $ORIGINAL_DIR
# Create a symlink to the docroot.
ln -sf $ACTUAL_DIR/docroot $DOCROOT

# Copy the existing settings.php to the new site, but add a database prefix.
cat $SETTINGS |
# Sets the database prefix to the prefix line starting only with whitespace.
sed -e "s/^\(\s*\)'prefix'\ =>\ '',/\1'prefix'\ =>\ '$DB_PREFIX',/" \
# Then saves the settings.php file to the new location.
> $NEW_SETTINGS

echo "Copied $SETTINGS to $NEW_SETTINGS"

# Copy all the database tables, using the new prefix.
$DRUSH $ALIAS scr ${WORKSPACE}/copy_tables.php $PREFIX $DB_PREFIX

cd $ACTUAL_DIR
git checkout -b $BRANCH
git checkout master
git pull
git merge $BRANCH -m "Jenkins test merge into master."

echo "Checked out a new branch for this pull request, and merged it to master."

# Rsync the files over as well.
cd $DOCROOT
$DRUSH -y rsync $ALIAS:%files @self:%files
