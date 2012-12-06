#!/usr/bin/env bash
set -e

# The directory this script is in.
REAL_PATH=`readlink -f "${BASH_SOURCE[0]}"`
SCRIPT_DIR=`dirname "$REAL_PATH"`

usage() {
  cat $SCRIPT_DIR/README.md |
  # Remove ticks and stars.
  sed -e "s/[\`|\*]//g"
}

# Parse options.
WEBROOT=$WORKSPACE
DRUSH="drush"
WEBGROUP=
VERBOSE=""
GHPRID=
EXTRA_SETTINGS=""

while getopts “hi:l:d:g:e:v” OPTION; do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    i)
      GHPRID=$OPTARG
      ;;
    l)
      WEBROOT=$OPTARG
      ;;
    d)
      DRUSH=$OPTARG
      ;;
    e)
      EXTRA_SETTINGS=$OPTARG
      ;;
    v)
      VERBOSE="--verbose"
      ;;
    g)
      WEBGROUP=$OPTARG
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

# Remove the switches we parsed above from the arguments.
shift `expr $OPTIND - 1`

# Now, parse arguments.
SOURCE=$1
URL=${2:-http://default}

# If we're missing some of these variables, show the usage and throw an error.
if [[ -z $WEBROOT ]] || [[ -z $SOURCE ]] || [[ -z $GHPRID ]]; then
  usage
  exit 1
fi

# Put drush in verbose mode, if requested, and include our script dir so we have
# access to our custom drush commands.
DRUSH="$DRUSH $VERBOSE --include=$SCRIPT_DIR"
# The docroot of the new Drupal directory.
DOCROOT=$WEBROOT/$GHPRID
# The base prefix to use for the database tables.
PREFIX="pr_"
# The unique prefix to use for just this pull request.
DB_PREFIX="${PREFIX}${GHPRID}_"
# The drush options for the Drupal destination site. Eventually, we could open
# this up to allow users to specify a drush site alias, but for now, we'll just
# manually specify the root and uri options.
DESTINATION="--root=$DOCROOT --uri=$URL"

# Check to make sure drush is working properly, and can access the source site.
$DRUSH $SOURCE status --quiet

# Copy the existing settings.php to the new site, but add a database prefix.
$DRUSH $DESTINATION --yes --extra-settings="$EXTRA_SETTINGS" clone-settings-php $SOURCE $DB_PREFIX

# Copy all the database tables, using the new prefix.
$DRUSH $SOURCE --yes clone-db-prefix $DB_PREFIX $PREFIX

# Now, rsync the files over.
DESTINATION_FILES=`$DRUSH $DESTINATION dd files`
$DRUSH $DESTINATION -y rsync $SOURCE:%files @self:%files

if [[ $WEBGROUP ]]; then
  chgrp -R $WEBGROUP $DESTINATION_FILES
  echo "Set group on $DESTINATION_FILES to $WEBGROUP."
fi

echo "Rsynced the files directory."

# Clear the caches, for good measure.
$DRUSH $DESTINATION cc all
