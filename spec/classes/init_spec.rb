require 'spec_helper'

describe 'realmd' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      let(:params) do
        {
          domain:      'example.com',
          ad_username: 'join_user',
          ad_password: RSpec::Puppet::Sensitive.new('topsecret'),
          sssd_config: {
            'sssd'               => { 'services' => %w[nss pam] },
            'domain/example.com' => { 'ad_domain' => 'example.com' },
          },
          ou:     %w[servers linux],
          groups: %w[admins superadmins],
        }
      end

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('realmd') }

      # Regression (2.1.4): the guard must validate the join against AD
      # (adcli testjoin), not just the local realmd config (realm list), so a
      # transient config state cannot silently drop the node out of the domain.
      it 'validates the join against AD in the leave-stale-domain guard' do
        is_expected.to contain_exec('leave stale domain')
          .with_command('realm leave')
          .with_provider('shell')
          .with_unless(%r{adcli testjoin})
        is_expected.not_to contain_exec('leave stale domain').with_unless(%r{realm list})
      end

      # Regression (2.1.4): the AD password is fed to `realm join` via stdin from
      # an agent-unwrapped env var, never interpolated onto the command line
      # (where it would leak into the catalog/reports and `ps`).
      it 'joins the realm without the password on the command line' do
        is_expected.to contain_exec('join realm')
          .with_command(%r{\Aprintf '%s'})
          .with_command(%r{realm join})
        is_expected.not_to contain_exec('join realm').with_command(%r{topsecret})
      end
    end
  end
end
