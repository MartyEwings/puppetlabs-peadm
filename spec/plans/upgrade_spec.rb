require 'spec_helper'

describe 'peadm::upgrade' do
  # Include the BoltSpec library functions
  include BoltSpec::Plans

  def allow_standard_non_returning_calls
    allow_apply
    allow_any_task
    allow_any_plan
    allow_any_command
    allow_out_message
  end

  let(:trusted_primary) do
    JSON.parse File.read(File.expand_path(File.join(fixtures, 'plans', 'trusted-primary.json')))
  end

  let(:trusted_compiler) do
    JSON.parse File.read(File.expand_path(File.join(fixtures, 'plans', 'trusted-compiler.json')))
  end

  it 'minimum variables to run' do
    allow_standard_non_returning_calls

    expect_task('peadm::read_file').always_return({ 'content' => 'mock' })
    expect_task('peadm::cert_data').return_for_targets('primary' => trusted_primary)

    expect(run_plan('peadm::upgrade',
                    'primary_host' => 'primary',
                    'version' => '2019.8.6')).to be_ok
  end

  it 'runs with a primary, compilers, but no replica' do
    allow_standard_non_returning_calls

    expect_task('peadm::read_file').always_return({ 'content' => 'mock' })
    expect_task('peadm::cert_data').return_for_targets('primary' => trusted_primary,
                                                       'compiler' => trusted_compiler)

    expect(run_plan('peadm::upgrade',
                    'primary_host' => 'primary',
                    'compiler_hosts' => 'compiler',
                    'version' => '2019.8.6')).to be_ok
  end
end
