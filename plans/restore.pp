# @summary Restore the core user settings for puppet infrastructure from backup
#
# This plan can restore data to puppet infrastructure for DR and rebuilds
# 
plan peadm::backup (
  # Standard
  Peadm::SingleTargetSpec           $primary_host,
  Optional[Peadm::SingleTargetSpec] $replica_host            = undef,

  # Large
  Optional[TargetSpec]              $compiler_hosts          = undef,

  # Extra Large
  Optional[Peadm::SingleTargetSpec] $primary_postgresql_host = undef,
  Optional[Peadm::SingleTargetSpec] $replica_postgresql_host = undef,

  # Which data to restore
  Boolean                            $restore_orchestrator    = true,
  Boolean                            $restore_rbac            = true,
  Boolean                            $restore_activity        = true,
  Boolean                            $restore_ca_ssl          = true,
  Boolean                            $restore_puppetdb        = false,
  Boolean                            $restore_classification  = true,
  String                             $input_directory       = '/tmp',
  Timestamp                          $backup_timestamp,
){

  $backup_directory = "${input_directory}/pe-backup-${backup_timestamp}"
  # Check backup exists folder

  # Create an array of the names of databases and whether they have to be backed up to use in a lambda later
  $database_to_restore = [ $backup_orchestrator, $backup_activity, $backup_rbac, $backup_puppetdb]
  $database_names      = [ 'pe-orchestrator' , 'pe-activity' , 'pe-rbac' , 'pe-puppetdb' ]

  peadm::assert_supported_bolt_version()

  # Ensure input valid for a supported architecture
  $arch = peadm::assert_supported_architecture(
    $primary_host,
    $replica_host,
    $primary_postgresql_host,
    $replica_postgresql_host,
    $compiler_hosts,
  )

  if $restore_classification {
    out::message('# Restoring classification')
    run_task('peadm::restore_classification', $primary_host,
    directory => "$backup_directory",
    )
  }

  if $backup_ca_ssl {
    out::message('# Restoring ca and ssl certificates')
    run_command("/opt/puppetlabs/bin/puppet-backup restore ${backup_directory}/ --scope=certs", $primary_host)
  }

  # Check if /etc/puppetlabs/console-services/conf.d/secrets/keys.json exists and if so back it up
  out::message('# Backing up ldap secret key if it exists')
  run_command("test -f /etc/puppetlabs/console-services/conf.d/secrets/keys.json && cp -rp /etc/puppetlabs/console-services/conf.d/secrets/keys.json ${backup_directory} || echo secret ldap key doesnt exist" , $primary_host) # lint:ignore:140chars

  # IF backing up orchestrator back up the secrets too /etc/puppetlabs/orchestration-services/conf.d/secrets/
  if $backup_orchestrator {
    out::message('# Backing up orchestrator secret keys')
    run_command("cp -rp /etc/puppetlabs/orchestration-services/conf.d/secrets ${backup_directory}/", $primary_host)
  }

  $database_to_backup.each |Integer $index, Boolean $value | {
    if $value {
    out::message("# Backing up database ${database_names[$index]}")
      # If the primary postgresql host is set then pe-puppetdb needs to be remotely backed up to primary.
      if $database_names[$index] == 'pe-puppetdb' and $primary_postgresql_host {
        run_command("sudo -u pe-puppetdb /opt/puppetlabs/server/bin/pg_dump \"sslmode=verify-ca host=${primary_postgresql_host} sslcert=/etc/puppetlabs/puppetdb/ssl/${primary_host}.cert.pem sslkey=/etc/puppetlabs/puppetdb/ssl/${primary_host}.private_key.pem sslrootcert=/etc/puppetlabs/puppet/ssl/certs/ca.pem dbname=pe-puppetdb\" -f /tmp/puppetdb_$(date +%F_%T).bin" , $primary_host) # lint:ignore:140chars
      } else {
        run_command("sudo -u pe-postgres /opt/puppetlabs/server/bin/pg_dump -Fc \"${database_names[$index]}\" -f \"${backup_directory}/${database_names[$index]}_$(date +%F_%T).bin\"" , $primary_host) # lint:ignore:140chars
      }
    }
  }
}
