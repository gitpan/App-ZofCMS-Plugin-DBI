use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'App::ZofCMS::Plugin::DBI',
    license             => 'perl',
    dist_author         => 'Zoffix Znet <zoffix@cpan.org>',
    dist_version_from   => 'lib/App/ZofCMS/Plugin/DBI.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Carp'        => 1.04,
        'DBI'         => 1.602,
        'perl'        => '5.006',
    },
    configure_requires => { 'Module::Build' => 0 },
    add_to_cleanup      => [ 'App-ZofCMS-Plugin-DBI-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
