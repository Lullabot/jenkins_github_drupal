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
VERBOSE=
GHPRID=
EXTRA_SETTINGS=
HARDLINKS=
DEBUG=

while getopts “hH:i:l:d:g:e:vx” OPTION; do
  case $OPTION in
    h)
      usage
      exit
      ;;
    H)
      if [[ ! -d $OPTARG ]]; then
        echo "The $OPTARG directory does not exist. Please choose a directory that contains an identical copy of the files directory."
        exit 1
      fi
      HARDLINKS="--link-dest=\"$OPTARG\""
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
    x)
      set -x
      DEBUG="--debug"
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
if [[ -z $WEBROOT ]]; then
  echo "You must specify a webroot."
  exit 1
fi
if [[ -z $SOURCE ]]; then
  echo "You must specify a source alias."
  exit 1
fi
if [[ -z $GHPRID ]]; then
  echo "You must specify a github pull request id."
  exit 1
fi

# Put drush in verbose mode, if requested, and include our script dir so we have
# access to our custom drush commands.
DRUSH="$DRUSH $VERBOSE $DEBUG --include=$SCRIPT_DIR"
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

# Drop all database tables with this prefix first, in case the environment is
# being rebuilt, and new tables were created in the environment.
$DRUSH $SOURCE --yes drop-prefixed-tables $DB_PREFIX

# Copy all the database tables, using the new prefix.
$DRUSH $SOURCE --yes clone-db-prefix $DB_PREFIX $PREFIX

# Now, rsync the files over. If we have a webgroup, set the sticky bit on the
# directory before rsyncing. We then rsync with --no-p, --no-o, and
# --omit-dir-times, to avoid errors. There are dynamically created directories
# we can exclude as well, such as css, js, styles, etc.
if [[ $WEBGROUP ]]; then
  DESTINATION_FILES=`$DRUSH $DESTINATION dd files`
  mkdir -p -m 2775 "$DESTINATION_FILES"
  chgrp $WEBGROUP $DESTINATION_FILES
fi
$DRUSH $DESTINATION -y rsync $HARDLINKS \
  $SOURCE:%files @self:%files \
  --omit-dir-times --no-p --no-o \
  --exclude-paths="css:js:styles:imagecache:ctools"
