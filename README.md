# realmd

#### Table of Contents

1. [Description](#description)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

Realmd support for RHEL
Originally developed and maintained by [Geoff Williams](https://forge.puppet.com/modules/geoffwilliams/realmd).
This module was created to support Redhat 8 or 9 (which the current Geoff Willams one doesn't)
Other than adding the RHEL8 (and RHEL9) support, this module remains the same.

## Features

* Join a single domain
* Re-join to a different domain if `realm list --name-only` doesn't agree with the `domain` parameter
* `simple_allow_groups` used for access control

## Usage
See reference and examples

## Limitations
* Not supported by Puppet, Inc.
* Supports joining a single realm only
* Rewrites `/etc/sssd/sssd.conf` (template)
* `simple_allow_groups` used for access control

## Development

PRs accepted :)

## Testing
This module supports testing using [PDQTest](https://github.com/declarativesystems/pdqtest).


Test can be executed with:

```
bundle install
make
```

See `.travis.yml` for a working CI example
