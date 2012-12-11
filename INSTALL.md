## Jenkins Github Drupal Pull Request Builder.sh

### Steps to Install:

```bash
cd ~
git clone git://github.com/Lullabot/jenkins_github_drupal.git
sudo mv jenkins_github_drupal /usr/local/share
```

#### If you'd like easy access to the scripts in this repo, create symlinks.

```bash
sudo ln -s /usr/local/share/jenkins_github_drupal/cleanup.sh \
  /usr/local/bin/jgd-cleanup
sudo ln -s /usr/local/share/jenkins_github_drupal/clone_site.sh \
  /usr/local/bin/jgd-clone-site
sudo ln -s /usr/local/share/jenkins_github_drupal/github_comment.sh \
  /usr/local/bin/jgd-github-comment
sudo ln -s /usr/local/share/jenkins_github_drupal/prepare_dir.sh \
  /usr/local/bin/jgd-prepare-dir
```

#### Test out the scripts, by calling each of them with the help option.
```bash
jgd-cleanup -h
jgd-clone-site -h
jgd-github-comment -h
jgd-prepare-dir -h
```

#### Install some Jenkins plugins we'll need:

1. Log into Jenkins
1. Go to Manage Jenkins
1. Click on Manage Plugins
1. Click on Available Plugins
1. Install these plugins
 * EnvInject Plugin
 * Github pull requests builder

Note: _You must restart Jenkins after installing these plugins, otherwise expect errors._

Some nice to have Plugins:

* Color Ansi plugin, to show Drush colored output for errors and warnings.
* Log Parser plugin, with Drush rules to log errors and warnings in Jenkins based on the same from drush command output.

After the Log Parser plugin is installed, you'll need to add Drush rules.

1. Log in as jenkins
```bash
sudo su - jenkins
```
1. Create a log-parser-rules directory in the homedir.
```bash
mkdir ~/log-parser-rules
```
1. Use the Drush log parser rules from https://gist.github.com/4236526
```bash
wget -O ~/log-parser-rules/drush \
  https://raw.github.com/gist/4236526/jenkins_log_parser_drush
```

#### Configure Github pull request builder plugin
1. Go back to 'Manage Jenkins' and click on 'Configure System'
1. Down at the bottom under Github pull requests builder, enter the credentials for Github "bot" user, for instance, `serverbots`.
1. Enter the admin list. 'Admins' are users that can kick off builds of the jobs by typing comments on the Pull Request. Separate each user with spaces.
1. Click Advanced in that same area if you'd like to change the regex expression to look for to kick off jobs

#### Setting up the Pull Request environment
You need to have a webroot that Jenkins can write to for this job. This requires an Apache Vhost or Nginx server spec that allows subdirectories, and following symlinks. For example, say you have a staging site at http://stage.example.com. You might want to create another site at http://pull-request.example.com, or http://pr.stage.example.com, etc. You then need a directory that is writable by the Jenkins user that this vhost points to. Note that if you are executing this job on a Jenkins node, the user the command is being executed as may not be jenkins. Adjust the following accordingly. You will also want to make sure that the Jenkins user is in the web group, such as www-data, or apache, or whatever group your web server runs as.

1. Add the jenkins user to the www-data group.
```bash
sudo usermod -a -G jenkins www-data
```
1. Create pull-requests/example.com
```bash
sudo mkdir -p /var/www/pull-requests/example.com
```
1. Make the Jenkins user the owner of this directory.
```bash
sudo chown -R jenkins:www-data /var/www/pull-requests
```
1. Optionally, preserve the www-data group on this directory.
```bash
sudo chmod 2775 /var/www/pull-requests
```

#### Create a new Jenkins job
As always, name the job with underscores, not spaces. For instance Stage_Example_Pull_Request_Builder. I like to prefix all job names consistently, based on Environment and Project, so you can set up groups that match on these names in Jenkins easily.

Note: _While you are creating and editing the job, it is best to save often, as some of these plugins seem a bit flaky._

1. Choose Build a free-style software project, unless you already have a Pull Request job you can clone.
1. Under Source Code Management, choose 'Git'
1. Enter your github repository URL, the URL you use to clone the repo.
1. Click Advanced underneath this field
1. Under Refspec, enter +refs/pull/*:refs/remotes/origin/pr/*
1. Branch Specifier should be ${sha1}
1. Click Advanced under the branch
1. Set Local subdirectory for repo (optional) to new_pull_request
1. Scroll down to Build Triggers
1. Click Github pull requests builder
1. Under Build Environment, click Inject passwords to the build as environment variables
1. Click Add
1. Type GITHUB_TOKEN under name
1. Enter your bot user's github token in password. For serverbots, it's on the DR page. If you need to create one, do the following, replacing [github-bot-username] with your github bot username:
1. curl -u [github-bot-username] https://api.github.com/authorizations -d '{"scopes":["repo"]}'
1. Under Build Steps, choose Execute Shell
1. See https://gist.github.com/4236407 for an example script to call.
1. If you have the Log Parser plugin, under Post-Build-Actions choose Console output (build log) parsing
1. Choose Drush, and mark failed on error, unstable on warning.

#### Build a job to tear down the environment

Often you'd like to be able to tear down these environments after they are tested and merged. You can create a Jenkins job to handle this for you with minimal effort.

1. Create a new job, choosing, Build a free-style software project again.
1. Name the job example_com_pull_request_tear_down or something like that. Just try to keep it consistent, mkay? ;)
1. Check the This build is parameterized checkbox.
1. Click Add Parameter and choose String Parameter.
1. Under name specify GHPRID
1. Under Description specify The github pull request ID.
1. Click Add build step under Build.
1. Choose Execute shell.
1. In the shell, do something like the following:
```bash
jgd-cleanup -i "$GHPRID" -l "/srv/www/pull-requests/example.com"
```
1. If you have the Log Parser plugin, under Post-Build-Actions choose Console output (build log) parsing
1. Choose Drush, and mark failed on error, unstable on warning.
