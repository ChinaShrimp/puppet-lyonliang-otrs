define otrs::install() {
    $basepackages = [
        'libapache2-mod-perl2',         
        'libdbd-mysql-perl',         
        'libtimedate-perl',         
        'libnet-dns-perl',         
        'libnet-ldap-perl',         
        'libio-socket-ssl-perl',         
        'libpdf-api2-perl',         
        'libsoap-lite-perl',         
        'libtext-csv-xs-perl',         
        'libjson-xs-perl',         
        'libapache-dbi-perl',         
        'libxml-libxml-perl',         
        'libxml-libxslt-perl',         
        'libyaml-perl',         
        'libarchive-zip-perl',         
        'libcrypt-eksblowfish-perl',         
        'libencode-hanextra-perl',         
        'libmail-imapclient-perl',         
        'libtemplate-perl'
    ]

    package { $basepackages:
        ensure  => present,
        notify  => Class['apache'],
    }

    vcsrepo { '/opt/otrs':
        ensure   => present,
        provider => git,
        source   => 'https://github.com/OTRS/otrs.git',
        revision => 'rel-5_0',
    } ->
    exec { 'cp Kernel/Config.pm.dist Kernel/Config.pm':
        cwd     => '/opt/otrs',
        creates => '/opt/otrs/Kernel/Config.pm',
        path    => ['/bin', '/usr/bin', '/usr/sbin'],
    }

    vcsrepo { '/opt/module-tools':
        ensure   => present,
        provider => git,
        source   => 'https://github.com/OTRS/module-tools.git',
        revision => 'master',
    }

    # install and config apache/modules
    class { 'apache': 
        confd_dir   => '/etc/apache2/conf-enabled',
    }
    class { 'apache::mod::perl': }
    class { 'apache::mod::headers': }

    user { 'otrs':
        ensure  => present,
        home    => '/opt/otrs',
        groups  => 'www-data',
        comment => 'OTRS user',
        require => Class['apache'],
    } ->
    exec { '/opt/otrs/bin/otrs.SetPermissions.pl --web-group=www-data':
        cwd     => '/opt/otrs',
        path    => '/bin:/sbin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin',
        require => Vcsrepo['/opt/otrs'],
    }

    # setup otrs apache vhost config file
    file { '/etc/apache2/conf-available/zzz_otrs.conf':
        ensure  => link,
        target  => '/opt/otrs/scripts/apache2-httpd.include.conf',
        require => Class['apache'],
    } ~>
    exec { 'a2enconf zzz_otrs': 
        cwd     => '/etc/apache2/conf-available/',
        path    => '/bin:/sbin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin',
    }

   	class {'::mysql::server':
        package_name     => 'mariadb-server',
        service_name     => 'mysql',
        root_password    => 'changeme',
        override_options => {
            mysqld => {
              'log-error' => '/var/log/mysql/mariadb.log',
              'pid-file'  => '/var/run/mysqld/mysqld.pid',
              'max_allowed_packet' => '20M',
              'query_cache_size' => '32M',
              'innodb_log_file_size' => '256M',
            },
            mysqld_safe => {
              'log-error' => '/var/log/mysql/mariadb.log',
            },
        }
	}       
}
