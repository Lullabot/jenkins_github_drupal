#!/usr/bin/env bash
set -e

# The directory this script is in.
REAL_PATH=`readlink -f "${BASH_SOURCE[0]}"`
SCRIPT_DIR=`dirname "$REAL_PATH"`

usage() {
cat << EOF
  usage: github_comment.sh -a <[github_account]/[github_project]> -i <issue_number> -b <body> <<< "<github_token>"

OPTIONS

<[github_account]/[github_project]>

-a
  This is the project owner account and project, as you might see in the github
  URL. For instance, if you were going to post a comment on
  https://github.com/q0rban/foo, you would set -a to q0rban/foo.
-i
  The github issue number.
-b
  The body of the comment.

ARGUMENTS

<github_token>
  The Github authentication token. Pass this to stdin so that the value cannot
  be seen in ps. If using this within Jenkins, it is highly recommended to use
  the 'Inject passwords to the build environment as environment variables'
  option that comes with the Environment Injector Plugin.

EOF
}

# Parse options.
WEBROOT=$WORKSPACE
DRUSH="drush"
VERBOSE=""

while getopts "ha:i:b:" OPTION; do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    a)
      ACCOUNT_PROJECT=$OPTARG
      ;;
    i)
      ISSUE_NUMBER=$OPTARG
      ;;
    b)
      BODY=$OPTARG
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

# Remove the switches we parsed above from the arguments.
shift `expr $OPTIND - 1`

# Grab the token from STDIN.
read TOKEN

# If we're missing some of these variables, show the usage and throw an error.
if [[ -z $TOKEN ]] || [[ -z $ACCOUNT_PROJECT ]] || [[ -z $ISSUE_NUMBER ]] || [[ -z $BODY ]]; then
  usage
  exit 1
fi

# Ensure curl exists.
command -v curl >/dev/null 2>&1 || {
  echo >&2 "You must have cURL installed for this command to work properly.";
  exit 1;
}

URL="https://api.github.com/repos/$ACCOUNT_PROJECT/issues/$ISSUE_NUMBER/comments"
PUBLIC_URL="http://github.com/$ACCOUNT_PROJECT/issues/$ISSUE_NUMBER"
# Escape all single quotes.
BODY=${BODY//\'/\\\'}
DATA=`php -r "print json_encode(array('body' => '$BODY'));"`
OUTPUT=`curl -H "Authorization: token $TOKEN" POST -d "$DATA" $URL`

# Check for errors
ERROR=`php -r "\\$json = json_decode('$OUTPUT'); isset(\\$json->message) ? print \\$json->message : NULL;"`

if [[ -z $ERROR ]]; then
  echo "Comment posted successfully to $PUBLIC_URL."
  exit 0
fi

echo "Failed to post comment. Reason: $ERROR."
exit 1
