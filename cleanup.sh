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
DRUSH="drush"
WEBROOT=$WORKSPACE
VERBOSE=""

while getopts “hi:l:d:v” OPTION; do
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
    v)
      VERBOSE="--verbose"
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

# Remove the switches we parsed above from the arguments.
shift `expr $OPTIND - 1`

# If we're missing some of these variables, show the usage and throw an error.
if [[ -z $WEBROOT ]] || [[ -z $GHPRID ]]; then
  usage
  exit 1
fi

# Put drush in verbose mode, if requested, and include our script dir so we have
# access to our custom drush commands.
DRUSH="$DRUSH $VERBOSE --include=$SCRIPT_DIR"
# The docroot of the new Drupal directory.
DOCROOT="$WEBROOT/$GHPRID"
# The real directory of the docroot.
REAL_DOCROOT=`readlink -f "$DOCROOT"`
# The path of the repository.
ACTUAL_PATH=`dirname "$REAL_DOCROOT"`
# The unique prefix to use for just this pull request.
DB_PREFIX="pr_${GHPRID}_"
# The drush options for the Drupal destination site. Eventually, we could open
# this up to allow users to specify a drush site alias, but for now, we'll just
# manually specify the root and uri options.
DESTINATION="--root=$DOCROOT"

# Check to make sure drush is working properly, and can access the source site.
ALIASES=`$DRUSH $DESTINATION sa | grep -v ^@`

# If we didn't get any aliases, throw an error and quit.
if [[ -z $ALIASES ]]; then
  echo "No sites found at $DOCROOT."
  exit 1
fi

# Delete all prefixed tables.
for ALIAS in $ALIASES; do
  DESTINATION="$DESTINATION --uri=$ALIAS"
  $DRUSH $DESTINATION --yes drop-prefixed-tables $DB_PREFIX
done;

# Remove the symlink.
rm $DOCROOT
echo "Removed the $DOCROOT symlink."
# Remove the repository.
rm -rf $ACTUAL_PATH
echo "Removed $ACTUAL_PATH"
