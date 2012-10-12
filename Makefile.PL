use strict;
use warnings;
use inc::Module::Install;

perl_version ('5.0100');

name 'Ginger-Cookie';
all_from 'lib/Ginger/Cookies.pm';

requires 'Data::Clone'  => 0.003;
requires 'List::Util'   => 1.25;
requires 'Scalar::Util' => 1.25;
requires 'Class::Load'  => 0.20;
requires 'Any::Moose'   => 0.18;
requires 'Mouse'        => 1.02;

test_requires 'Test::More';

#auto_include_deps;

WriteAll;
