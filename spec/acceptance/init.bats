@test "group admins added to config file" {
    grep admins /etc/sssd/sssd.conf
}

@test "group superadmins added to config file" {
    grep superadmins /etc/sssd/sssd.conf
}

@test "groups with spaces handled correctly" {
    grep ",domain admins" /etc/sssd/sssd.conf
}

@test "correct domain was joined" {
    realm list --name-only | grep 'realm$'
}

