@test "domain rejoined OK" {
    realm list --name-only | grep '^newrealm$'
}