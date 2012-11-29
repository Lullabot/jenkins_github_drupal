#!/usr/bin/env bash
set -e

# The directory this script is in, so we can call the PHP scripts via drush.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

usage() {
  cat $SCRIPT_DIR/README.md
}

WEBROOT=$WORKSPACE
URL="http://default"
ALIAS=$1
DRUSH="drush"
VERBOSE=""

while getopts “hl:u:d:v” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    l)
      WEBROOT=$OPTARG
      ;;
    u)
      URL=$OPTARG
      ;;
    d)
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
if [[ -z $WEBROOT ]] || [[ -z $ALIAS ]]; then
  usage
  exit 1
fi

if [[ -z $sha1 ]] || [[ -z $WORKSPACE ]]; then
  echo "This script must be executed from within a proper Jenkins job."
  exit 1
fi

# Put drush in verbose mode, if requested.
DRUSH="$DRUSH $VERBOSE"
# Pull out the Pull Request ID from the origin.
GHPRID=`echo $sha1 | grep -o '[0-9]'`
# This is the directory of the checked out pull request, from Jenkins.
ORIGINAL_DIR="${WORKSPACE}/new_pull_request"
# The directory where the checked out pull request will reside.
ACTUAL_DIR="${WORKSPACE}/${GHPRID}-actual"
# The directory where the docroot will be symlinked to.
DOCROOT=$WEBROOT/$GHPRID
# The command will attempt to merge master with the pull request.
BRANCH="pull-request-$GHPRID"

# Check to make sure drush is working.
$DRUSH $ALIAS status --quiet

SETTINGS="`$DRUSH $ALIAS dd`/`$DRUSH $ALIAS status site_path --pipe`/settings.php"
SETTINGS_DIR=`echo $URL |
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
# Then, sets the database prefix to the prefix line starting only with
# whitespace and then saves the settings.php file to the new location.
sed -e "s/^\(\s*\)'prefix'\ =>\ '',/\1'prefix'\ =>\ '$DB_PREFIX',/" > $NEW_SETTINGS

echo "Copied $SETTINGS to $NEW_SETTINGS"

# Copy all the database tables, using the new prefix.
$DRUSH $ALIAS scr $SCRIPT_DIR/copy_tables.php $PREFIX $DB_PREFIX

cd $ACTUAL_DIR
git checkout -b $BRANCH
git checkout master
git pull
git merge $BRANCH -m "Jenkins test merge into master."

echo "Checked out a new branch for this pull request, and merged it to master."

# Rsync the files over as well.
cd $DOCROOT
$DRUSH -y rsync $ALIAS:%files @self:%files

echo "Rsynced the files directory."
