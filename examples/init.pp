
#@PDQTest
class { "realmd":
  domain      => "realm",
  ad_username => "join_user",
  ad_password => "topsecret",
  ou          => ['linux', 'main'],
  groups      => ['admins', 'superadmins', 'domain admins'],
}
