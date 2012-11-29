<?php

/**
 * @file
 * Drush commands for Jenkins Github Drush.
 */

/**
 * Implements hook_drush_help().
 */
function jgd_drush_help($section) {
  switch ($section) {
    case 'drush:clone-db-prefix':
      return dt('Clones a database to itself, adding a table prefix.');
    case 'drush:drop-prefixed-tables':
      return dt('Drops all tables in a database matching a specified prefix.');
    case 'drush:clone-settings-php':
      return dt('Clone a settings.php file to a new site.');
  }
}

/**
 * Implements hook_drush_command().
 */
function jgd_drush_command() {
  $items['clone-db-prefix'] = array(
    'description' => 'Clones a database to itself, adding a table prefix.',
    'bootstrap' => DRUSH_BOOTSTRAP_DRUPAL_DATABASE,
    'arguments' => array(
      'prefix' => dt('The database table prefix to use.'),
      'ignored_prefix' => dt('The prefix of tables to not clone, useful if the database has been cloned previously.'),
    ),
    'required-arguments' => 1,
  );
  $items['drop-prefixed-tables'] = array(
    'description' => 'Drops all tables in a database matching a specified prefix.',
    'bootstrap' => DRUSH_BOOTSTRAP_DRUPAL_DATABASE,
    'arguments' => array(
      'prefix' => dt('The prefix of tables to delete.'),
    ),
  );
  $items['clone-settings-php'] = array(
    'description' => "Clone a settings.php file to this site.",
    'bootstrap' => DRUSH_BOOTSTRAP_DRUPAL_DATABASE,
    'arguments' => array(
      'site_alias' => dt('Drush site alias of the site to clone from.'),
      'prefix' => dt('An optional table prefix to add to the database array in the settings.php file.'),
    ),
    'required-arguments' => 1,
  );

  return $items;
}

/**
 * Command callback for clone-db-prefix.
 */
function drush_jgd_clone_db_prefix($prefix, $ignored_prefix = NULL) {
  $dt_args['@prefix'] = $prefix;

  if (!drush_confirm(dt('All database tables prefixed with @prefix will be destroyed and recreated. There is no undo. Are you sure you want to proceed?', $dt_args))) {
    return FALSE;
  }

  $creds = drush_get_context('DRUSH_DB_CREDENTIALS');
  $db_name = $creds['name'];

  if (isset($ignored_prefix)) {
    $sql = "SHOW TABLES WHERE tables_in_$db_name NOT LIKE '$ignored_prefix%'";
  }
  else {
    $sql = "SHOW TABLES";
  }
  $tables = db_query($sql)->fetchCol();

  if (empty($tables)) {
    drush_log(dt('There were no database tables to clone.'), 'error');
    return FALSE;
  }

  dlm($tables);

  try {
    foreach ($tables as $table) {
      $dt_args['@new-table'] = $new_table_name = "$prefix$table";
      $dt_args['@table'] = $table;

      // Drop the existing table, if it's there.
      drush_log(dt('Dropping table @new-table.', $dt_args));
      db_drop_table($new_table_name);

      // Create the new table.
      drush_log(dt('Creating table @new-table from @table.', $dt_args));
      db_query("CREATE TABLE $new_table_name LIKE $table");

      // Insert all the data into the new table.
      drush_log(dt('Copying data from @table to @new-table.', $dt_args));
      db_query("INSERT INTO $new_table_name SELECT * FROM $table");

      // If we got this far, we succeeded!
      $dt_args['@successes']++;
    }
  }
  catch (Exception $e) {
    drush_log((string) $e, 'error');
    return FALSE;
  }

  drush_log(dt('Cloned @successes database tables, prefixing with @prefix.', $dt_args), 'completed');
}

function drush_jgd_drop_prefixed_tables($prefix) {
  $dt_args['@prefix'] = $prefix;

  if (!drush_confirm(dt('All database tables prefixed with @prefix will be destroyed. There is no undo. Are you sure you want to proceed?', $dt_args))) {
    return FALSE;
  }

  if (!$prefix) {
    drush_set_error('NO_DB_PREFIX', dt('You must specify a database prefix.'));
    return FALSE;
  }

  $creds = drush_get_context('DRUSH_DB_CREDENTIALS');
  $db_name = $creds['name'];

  $sql = "SHOW TABLES LIKE :prefix";
  $tables = db_query($sql, array(':prefix' => "$prefix%"))->fetchCol();

  if (empty($tables)) {
    drush_log(dt('There were no database tables to remove.'), 'status');
    return;
  }

  dlm($tables);

  try {
    array_walk($tables, 'db_drop_table');
  }
  catch (Exception $e) {
    drush_log((string) $e, 'error');
    return FALSE;
  }

  $dt_args['@count'] = count($tables);
  drush_log(dt('Deleted @count database tables with prefix @prefix.', $dt_args), 'completed');
}

/**
 * Command callback for clone-settings-php.
 */
function drush_jgd_clone_settings_php($site_alias, $prefix = NULL) {
  // Normalize the alias to have a leading @ symbol.
  $dt_args['@alias'] = $site_alias = '@' . ltrim($site_alias, '@');

  if (!($source_record = drush_sitealias_get_record($site_alias))) {
    drush_log(dt('No @alias alias was found.', $dt_args), 'error');
    return FALSE;
  }
  dlm($source_record);

  $destination_record = drush_sitealias_get_record('@self');
  dlm($destination_record);

  // Load up the status stuff so we can get the conf_path(). Wish there was
  // another way of doing this.
  $results = drush_invoke_process($source_record, 'status', array(), array(), array('integrate' => FALSE));

  if (!isset($results['object']['Site path'])) {
    drush_log(dt('No source settings.php found from alias @alias.', $dt_args), 'error');
    return FALSE;
  }
  $dt_args['@source-settings'] = $source_settings_file = $source_record['root'] . '/'
    . $results['object']['Site path'] . '/settings.php';

  if (!file_exists($source_settings_file)) {
    drush_log(dt('No source settings.php found at @source-settings.', $dt_args), 'error');
    return FALSE;
  }

  if (!($source_settings = file_get_contents($source_settings_file))) {
    drush_log(dt('This command needs read privileges to file @source-settings.', $dt_args), 'error');
    return FALSE;
  }
}
