require 'spec_helper'

describe 'peadm::backup' do
  include BoltSpec::Plans
  let(:params) { { 'primary_host' => 'primary' } }

  it 'runs with default params' do
    expect_out_message.with_params('# Backing up ca and ssl certificates')
    expect_command('/opt/puppetlabs/bin/puppet-backup create --dir=/tmp --scope=certs')
    expect_out_message.with_params('# Backing up database pe-orchestrator')
    expect_command('sudo -u pe-postgres /opt/puppetlabs/server/bin/pg_dump -Fc "pe-orchestrator" -f "/tmp/pe-orchestrator_$(date +%Y%m%d%S).bin" || echo "Failed to dump database pe-orchestrator"')
    expect_out_message.with_params('# Backing up database pe-activity')
    expect_command('sudo -u pe-postgres /opt/puppetlabs/server/bin/pg_dump -Fc "pe-activity" -f "/tmp/pe-activity_$(date +%Y%m%d%S).bin" || echo "Failed to dump database pe-activity"')
    expect_out_message.with_params('# Backing up database pe-rbac')
    expect_command('sudo -u pe-postgres /opt/puppetlabs/server/bin/pg_dump -Fc "pe-rbac" -f "/tmp/pe-rbac_$(date +%Y%m%d%S).bin" || echo "Failed to dump database pe-rbac"')
    expect_out_message.with_params('# Backing up classification')
    expect_task('peadm::backup_classification')
    expect(run_plan('peadm::backup', params)).to be_ok
  end
end
