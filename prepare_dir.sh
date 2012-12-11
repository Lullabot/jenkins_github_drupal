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

GHPRID=
while getopts “hxi:” OPTION; do
  case $OPTION in
    h)
      usage
      exit
      ;;
    i)
      GHPRID=$OPTARG
      ;;
    x)
      set -x
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

# Remove the switches we parsed above.
shift `expr $OPTIND - 1`

# Now, parse the arguments.
WEBROOT=${1:-$WORKSPACE}

# If we're missing some of these variables, show the usage and throw an error.
if [[ -z $WEBROOT ]] || [[ -z $GHPRID ]]; then
  usage
  exit 1
fi

if [[ -z $WORKSPACE ]]; then
  echo "This script must be executed from within a proper Jenkins job."
  exit 1
fi

# This is the directory of the checked out pull request, from Jenkins.
ORIGINAL_DIR="${WORKSPACE}/new_pull_request"
# The directory where the checked out pull request will reside.
ACTUAL_DIR="${WORKSPACE}/${GHPRID}-actual"
# The directory where the docroot will be symlinked to.
DOCROOT=$WEBROOT/$GHPRID
# The command will attempt to merge master with the pull request.
BRANCH="pull-request-$GHPRID"

# Remove the existing .git dir if it exists.
rm -rf $ACTUAL_DIR/.git
# Copy the new_pull_request directory.
rsync -a ${ORIGINAL_DIR}/ $ACTUAL_DIR
# Now remove the new_pull_request directory.
rm -rf $ORIGINAL_DIR
# Create a symlink to the docroot, if it doesn't already exist.
if [ ! -h $DOCROOT -a -d $ACTUAL_DIR ];
then
  ln -sf $ACTUAL_DIR/docroot $DOCROOT
fi

cd $ACTUAL_DIR
git checkout -b $BRANCH
git checkout master
git pull
git merge $BRANCH -m "Jenkins test merge into master."

echo "Checked out a new branch for this pull request, and merged it to master."
