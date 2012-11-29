<?php

$prefix = $dt_args['@prefix'] = drush_shift();

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
  drush_set_error('EXCEPTION', (string) $e);
}

$dt_args['@count'] = count($tables);
drush_log(dt('Deleted @count database tables with prefix @prefix.', $dt_args), 'completed');

