use Test::More tests => 2;

use lib '../lib';
use Ginger::Cookies;

my $ginger1 = Ginger::Cookies->new;
my $ginger2 = Ginger::Cookies->new(
    trait => "HTTP::Cookies::Safari",
	file  => "$ENV{HOME}/Library/Cookies/Cookies.plist",
);

is( $ginger1->trait->isa('HTTP::Cookies') => 1 );
is( $ginger2->trait->isa('HTTP::Cookies') => 1 );

done_testing();

