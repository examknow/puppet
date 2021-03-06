# Class: openldap
#
# This class installs slapd and configures it with a single suffix hdb database
#
# Parameters:
#    $server_id
#       This openLDAP server's ID. Mostly used in replication environments, but
#       generally good to have. An integer. When using a multi-master setup or
#       mirrormode, the IDs of each server must be unique.
#    $datadir
#       The datadir this suffix will be installed, e.g. "/var/lib/ldap"
#    $master
#       Optional. In a replication environment, the TLS-enabled master's fqdn
#    $extra_schemas
#       Optional. A list of schema files relative to the /etc/ldap/schema directory
#    $extra_acls
#       Optional. Specify an ERB template file with additional ACL access rules
#       (in addition to the base rules)
#    $extra_indices
#       Optional. Specify an ERB template file with additional LDAP indices
#       (in addition to the base indices)
#    $size_limit
#       Optional. Specify the maximum number of entries to return from a search
#       operation. May be set to a number or to 'unlimited'. If unset, the default
#       is 2048.
#    $logging
#       Optional. Specify the kind of logging desired. Defaults to "sync"
#       And it is not named loglevel cause that's a puppet metaparameter
#    $hash_passwords
#       Optional. Specify what hashing scheme will be used by openldap to hash
#       cleartext passwords sent to it on account creation or password change.
#       Defauts to SHA. Valid values: SHA, SSHA, MD5, SMD5, CRYPT, SASL
#       Do not supply this if you don't know what you are doing!!!!
#    $read_only
#       Optional. Set to 'true' for read-only replica servers
#
# Actions:
#       Install/configure slapd
#
# Requires:
#
# Sample Usage:
#       class { '::openldap':
#           server_id = 1,
#           suffix = 'dc=example,dc=org',
#           datadir = '/var/lib/ldap',
#       }
class openldap(
    Integer $server_id,
    String $datadir,
    Optional[String] $master = undef,
    Optional[Array] $extra_schemas = undef,
    Optional[String] $extra_acls = undef,
    Optional[String] $extra_indices = undef,
    Optional[Integer] $size_limit = undef,
    String $logging = 'sync',
    String $hash_passwords = 'SHA',
    Boolean $read_only = false,
) {

    require_package('slapd', 'ldap-utils')

    service { 'slapd':
        ensure     => running,
        hasstatus  => true,
        hasrestart => true,
    }

    # our replication dir
    file { $datadir:
        ensure  => directory,
        recurse => false,
        owner   => 'openldap',
        group   => 'openldap',
        mode    => '0750',
        force   => true,
    }

    file { '/etc/ldap/slapd.conf' :
        ensure  => present,
        owner   => 'openldap',
        group   => 'openldap',
        mode    => '0440',
        content => template('openldap/slapd.erb'),
    }

    file { '/etc/default/slapd' :
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('openldap/default.erb'),
    }

    if $extra_schemas {
        openldap::ldap_schema { $extra_schemas: }
    }

    if $extra_acls {
        file { '/etc/ldap/acls.conf' :
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => template($extra_acls, 'openldap/base-acls.erb'),
        }
    } else {
        file { '/etc/ldap/acls.conf' :
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => template('openldap/base-acls.erb'),
        }
    }

    if $extra_indices {
        file { '/etc/ldap/indices.conf' :
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => template('openldap/base-indices.erb', $extra_indices),
        }
    } else {
        file { '/etc/ldap/indices.conf' :
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => template('openldap/base-indices.erb'),
        }
    }

    # We do this cause we want to rely on using slapd.conf for now
    exec { 'rm_slapd.d':
        onlyif  => '/usr/bin/test -d /etc/ldap/slapd.d',
        command => '/bin/rm -rf /etc/ldap/slapd.d',
    }


    file { '/etc/ldap/ldap.conf':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('openldap/ldap.conf.erb'),
    }

    # Relationships
    File['/etc/ldap/acls.conf'] -> File['/etc/ldap/slapd.conf']
    File['/etc/ldap/indices.conf'] -> File['/etc/ldap/slapd.conf']
    Package['slapd'] -> File['/etc/ldap/slapd.conf']
    Package['slapd'] -> File['/etc/default/slapd']
    Package['slapd'] -> File[$datadir]
    Package['slapd'] -> Exec['rm_slapd.d']
    Exec['rm_slapd.d'] -> Service['slapd']
    File['/etc/ldap/slapd.conf'] ~> Service['slapd'] # We also notify
    File['/etc/ldap/acls.conf'] ~> Service['slapd'] # We also notify
    File['/etc/ldap/indices.conf'] ~> Service['slapd'] # We also notify
    File['/etc/default/slapd'] ~> Service['slapd'] # We also notify
    File[$datadir] -> Service['slapd']
    File['/etc/ldap/ldap.conf'] -> Service['slapd']
}
