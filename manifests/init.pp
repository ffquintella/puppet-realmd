# @summary Support for Relmd+SSSD .
#
# @example joining a domain
#   class { "realmd":
#     domain      => "mydomain",
#     ad_username => "myuser",
#     ad_password => Sensitive("topsecret"),
#     ou          => ['linux', 'servers'],
#     groups      => ['admins', 'superadmins']
#   }
#
# @param packages List of packages to install to enable support (from in-module data)
# @param domain Domain to join
# @param ad_username AD Username to use for joining
# @param ad_password AD password to use for joining (Sensitive; from eyaml). Never interpolated into the join command line.
# @param ou Array of OUs to use for joining eg `foo,bar,baz` (OU= will be added for you)
# @param services List of services to enable for SSD/Realmd
# @param groups List of groups to add to `simple_allow_groups` (will be flattened for you)
# @param keytab_file Location of keytabs written by `realm` command
class realmd(
    Array[String] $packages = [],
    String        $domain,
    String           $ad_username,
    Sensitive[String] $ad_password,
    Hash          $sssd_config,
    Array[String] $ou,
    Array[String] $services     = ['sssd'],
    Array[String] $groups       = [],
    String        $keytab_file  = "/etc/krb5.keytab",
) {

  if $packages == [] {
    if $facts['os']['family'] == 'RedHat' {
      $packages_final = ['realmd', 'adcli', 'sssd', 'krb5-workstation', 'oddjob', 'oddjob-mkhomedir']
    }
        if $facts['os']['family'] == 'Debian' {
      $packages_final = ['realmd', 'adcli', 'krb5-user', 'sssd', 'sssd-tools', 'samba-common-bin', 'samba', 'libpam-modules', 'libpam-sss', 'libnss-sss']
    }
  } else {
    $packages_final = $packages
  }

  $_sssd_config = $realmd::sssd_config

  # flatten the array of $ou
  $_ou = $ou.map |$o| {
    "OU=${o}"
  }.join(",")

  Exec {
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
  }

  # if we are on a different domain, leave it now (deletes /etc/krb5.keytab)
  # Guard validates the join against AD using the machine credential (adcli testjoin),
  # not just the local realmd config (realm list). This avoids leaving a healthy domain
  # during a transient config state and silently dropping the node out of the domain.
  exec { "leave stale domain":
    provider => shell,
    command  => "realm leave",
    unless   => "!(test -f ${keytab_file}) || (adcli testjoin --domain=${shell_escape($domain)})",
  }

  -> package { $packages_final:
    ensure => present,
  }

  -> exec { "sssd SSH keypair":
    command => "ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key",
    creates => '/etc/ssh/ssh_host_dsa_key',
  }

  # The password is NOT interpolated into the command line: it would land in
  # cleartext in the compiled catalog/reports/PuppetDB and be visible in `ps`
  # (argv of the `sh -c` invocation) during the join. Instead it is unwrapped on
  # the agent (Deferred) into an environment variable that the command reads from
  # stdin, so it never appears in any process argv and is redacted from reports.
  -> exec { "join realm":
    provider    => shell,
    # NOTE: This MUST be a single top-level Deferred, not an array containing one.
    # Puppet only skips `environment` param validation when the parameter's
    # top-level value is a DeferredValue (parameter.rb#validate / type.rb#validate).
    # Wrapping it in an array hides the DeferredValue, so the validator runs
    # `value =~ /\w+=/` on it and dies with `undefined method '=~' for DeferredValue`.
    environment => Deferred('sprintf', ['REALMD_JOIN_PW=%s', Deferred('unwrap', [$ad_password])]),
    command     => "printf '%s' \"\$REALMD_JOIN_PW\" | realm join ${shell_escape($domain)} -U ${shell_escape($ad_username)} --computer-ou=${shell_escape($_ou)}",
    creates     => $keytab_file,
  }

  /*-> file { '/etc/sssd/sssd.conf':
    ensure  => present,
    content => epp('realmd/sssd.conf.epp', {domain => $domain, groups => $groups}),
    owner   => "root",
    group   => "root",
    mode    => '0600',
    notify  => Service[$services],
  }*/

  -> file { '/etc/sssd/sssd.conf':
    content => template('realmd/sssd.conf.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service[$services],
  }

  -> service { $services:
    ensure => running,
    enable => true,
  }

}

