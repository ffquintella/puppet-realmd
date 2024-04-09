# @summary Support for Relmd+SSSD .
#
# @example joining a domain
#   class { "realmd":
#     domain      => "mydomain",
#     ad_username => "myuser",
#     ad_password => "topsecret",
#     ou          => ['linux', 'servers'],
#     groups      => ['admins', 'superadmins']
#   }
#
# @param packages List of packages to install to enable support (from in-module data)
# @param domain Domain to join
# @param ad_username AD Username to use for joining
# @param ad_password AD password to use for joining
# @param ou Array of OUs to use for joining eg `foo,bar,baz` (OU= will be added for you)
# @param services List of services to enable for SSD/Realmd
# @param groups List of groups to add to `simple_allow_groups` (will be flattened for you)
# @param keytab_file Location of keytabs written by `realm` command
class realmd(
    Array[String] $packages,
    String        $domain,
    String        $ad_username,
    String        $ad_password,
    Array[String] $ou,
    Array[String] $services,
    Array[String] $groups       = [],
    String        $keytab_file  = "/etc/krb5.keytab",
) {

  if $packages == undef {
    if $['os']['family'] == 'RedHat'{
      $packages_final = ['realmd', 'adcli', 'sssd', 'krb5-workstation', 'oddjob', 'oddjob-mkhomedir']
    }
        if $['os']['family'] == 'Debian'{
      $packages_final = ['adcli', 'krb5-user', 'sssd', 'sssd-tools', 'samba-common-bin', 'samba', 'libpam-modules', 'libpam-sss', 'libnss-sss']
    }
  }else{
    $packages_final = $packages
  }


  # flatten the array of $ou
  $_ou = $ou.map |$o| {
    "OU=${o}"
  }.join(",")

  Exec {
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
  }

  # if we are on a different domain, leave it now (deletes /etc/krb5.keytab)
  exec { "leave stale domain":
    provider => shell,
    command  => "realm leave",
    unless   => "!(test -f ${keytab_file}) || (realm list --name-only | grep '^${shell_escape($domain)}\$')",

#    unless  => "!(test -f ${keytab_file}) || (test -f ${keytab_file} && realm list --name-only | grep '^${shell_escape($domain)}\$')",
  }

  -> package { $packages_final:
    ensure => present,
  }

  -> exec { "sssd SSH keypair":
    command => "ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key",
    creates => '/etc/ssh/ssh_host_dsa_key',
  }

  -> exec { "join realm":
    command =>
      "/bin/echo ${shell_escape($ad_password)} | \
      realm join ${shell_escape($domain)} -U ${shell_escape($ad_username)} --computer-ou=${shell_escape($_ou)}",
    creates => $keytab_file,
  }

  -> file { '/etc/sssd/sssd.conf':
    ensure  => present,
    content => epp('realmd/sssd.conf.epp', {domain => $domain, groups => $groups}),
    owner   => "root",
    group   => "root",
    mode    => '0600',
    notify  => Service[$services],
  }

  -> service { $services:
    ensure => running,
    enable => true,
  }

}

