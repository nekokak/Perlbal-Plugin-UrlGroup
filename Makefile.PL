use inc::Module::Install;
name 'Perlbal-Plugin-UrlGroup';
all_from 'lib/Perlbal/Plugin/UrlGroup.pm';

requires 'Perlbal';
requires 'URI::Escape';

use_test_base;
build_requires 'Test::Declare';

auto_install;
WriteAll;
