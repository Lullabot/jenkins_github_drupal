<?php

$ignored = drush_shift();
$prefix = $dt_args['@prefix'] = drush_shift();

if (!$ignored) {
  drush_set_error('NO_IGNORE_PREFIX', dt('You must specify the prefix for tables to ignore.'));
  return;
}
if (!$prefix) {
  drush_set_error('NO_DB_PREFIX', dt('You must specify a database prefix.'));
  return;
}

$creds = drush_get_context('DRUSH_DB_CREDENTIALS');
$db_name = $creds['name'];

$sql = "SHOW TABLES WHERE tables_in_$db_name NOT LIKE '$ignored%'";
$tables = db_query($sql)->fetchCol();

if (empty($tables)) {
  drush_set_error('NO_TABLES', dt('There were no database tables to clone.'));
  return;
}

try {
foreach ($tables as $table) {
  $new_table_name = "$prefix$table";
  $dt_args['@new-table'] = $new_table_name;
  $dt_args['@table'] = $table;
  drush_log(dt('Dropping table @new-table.', $dt_args));
  db_drop_table($new_table_name);
  drush_log(dt('Creating table @new-table from @table.', $dt_args));
  db_query("CREATE TABLE $new_table_name LIKE $table");
  drush_log(dt('Copying data from @table to @new-table.', $dt_args));
  db_query("INSERT INTO $new_table_name SELECT * FROM $table");
  $dt_args['@successes']++;
}
}
catch (Exception $e) {
  drush_set_error('EXCEPTION', (string) $e);
}

drush_log(dt('Cloned @successes database tables, prefixing with @prefix.', $dt_args), 'completed');

