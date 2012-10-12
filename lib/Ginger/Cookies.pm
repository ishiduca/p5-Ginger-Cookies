package Ginger::Cookies;
use 5.0100;
use strict;
our $VERSION = '0.01';

use Carp         qw(carp croak);
use Data::Clone  qw(clone);
use List::Util   qw(reduce);
use Scalar::Util qw(blessed);
use Class::Load  qw(try_load_class);
use Any::Moose;

has 'trait' => (
    is       => 'ro',
    isa      => 'HTTP::Cookies',
    required => 1,
);

sub BUILDARGS {
    my $class = shift;
    my %args  = @_;
    my $trait = delete $args{trait};

    given ($trait) {
        when (undef) {
            require HTTP::Cookies;
            $trait = HTTP::Cookies->new(%args);
        }
        when (blessed $_ && $_->isa('HTTP::Cookies')) {
            $trait = $_;
        }
        when (/^HTTP::Cookies/ && try_load_class($_)) {
            $trait = $_->new(%args);
        }
        default { croak q(! failed: value of "trait" attribute is wrong.) }
    }

    $args{trait} = $trait;
    \%args;
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;

sub load { shift->trait->load(@_) }

sub _scan {
    my($self, $cb, $cookie_jar, $ref) = @_;
    $ref = ($ref && $ref =~ /^array$/i) ? 'ARRAY' : 'HASH';
    while (my($domain, $paths) = each %{$cookie_jar}) {
        next if ref $paths ne 'HASH';
        while (my($path, $keys) = each %{$paths}) {
            next if ref $keys ne 'HASH';
            while (my($key, $vals) = each %{$keys}) {
                next if ref $vals ne $ref;
                $cb->($domain, $path, $key, $vals);
            }
        }
    }
}

sub cookie_jar {
    my $self = shift;
    my $cookie_jar = +{};

    $self->_scan(sub {
        my($domain, $path, $key, $vals) = @_;
        if (ref $vals ne 'ARRAY') {
            carp q(! failed: ref "vals" ne 'ARRAY');
            return;
        }
        my $emp = +{};
        $emp->{value}    = $vals->[1];
        $emp->{secure}   = $vals->[4] if $vals->[4];
        $emp->{_expires} = $vals->[5] if $vals->[5];
        $emp = reduce { $a->{lc $b} = $vals->[7]{$b}; $a }
                 $emp, keys %{$vals->[7]}
             if ref $vals->[7] eq 'HASH';
        $cookie_jar->{$domain}{$path}{$key} = $emp;
    }, clone($self->trait->{COOKIES}) => 'ARRAY');

    $cookie_jar->{version} = 1;
    $cookie_jar;
}

sub set_cookie {
    my $self = shift;
    my $cookie_jar = shift ||
        croak q(! failed: 2nd argument "cookie_jar" not found);
    $cookie_jar->{version} ne '1' and
        croak q(! failed: "version" not found in "cookie_jar");

    delete $cookie_jar->{version};

    $self->_scan(sub {
        my($domain, $path, $key, $vals) = @_;
        if (ref $vals ne 'HASH') {
            carp q(! failed: ref "vals" ne 'HASH');
            return;
        }
        my $cookie_jar = $self->trait;
        my @emp = ();
        $emp[0] = 0; # version 0 eq Cookie1, 1 eq Cookie2
        $emp[1] = $key;
        $emp[2] = delete $vals->{value};
        $emp[3] = $path;
        $emp[4] = $domain;
        $emp[5] = undef; # port
        $emp[6] = 0; # or 1, path_spec
        $emp[7] = delete $vals->{secure};
        $emp[8] = delete $vals->{_expires};
        $emp[9] = 0; # or 1, discard
        $emp[10] = reduce { $a->{$b} = $vals->{$b}; $a }
                     {}, keys %{$vals}
                 if keys %{$vals};
        $cookie_jar->set_cookie(@emp);
    }, clone $cookie_jar);
}

sub save {
    my $self = shift;
    $self->set_cookie(shift); # cookie_jar
    $self->trait->save(@_);
}

1;

__END__

=head1 NAME

Ginger::Cookies - save and load HTTP Cookie jars for AnyEvent::HTTP.

=head1 SYNOPSIS

  use AnyEvent;
  use AnyEvent::HTTP;
  use Ginger::Cookies;

  my $cookie_dat = './cookie.dat';
  my $ginger     = Ginger::Cookies->new;
  $ginger->load( $cookie_dat );

  # or
  # my $ginger = Ginger::Cookies->new(
  #     trait => HTTP::Cookies::Safari->new(
  #         file => "$ENV{HOME}/Library/Cookies/Cookies.plist",
  #     ),
  # );
  # or
  # my $ginger = Ginger::Cookies->new(
  #     trait => 'HTTP::Cookies::Safari',
  #     file => "$ENV{HOME}/Library/Cookies/Cookies.plist",
  # );

  my $cookie_jar = $ginger->cookie_jar;

  my $cv = AE::cv;
  http_get 'http://hoge.to/my_account',
      cookie_jar => $cookie_jar,
      sub {
          my($body, $hdr) = @_;
          if ($hdr->{Status} ne '200') {
              $cv->croak('! failed:' . $hdr->{Status} . ' ' . $hdr->{Reason});
              return;
          }
          if ($hdr->{URL} eq 'http://hoge.to/login') {
              $cv->croak('! failed: you need login');
              return;
          }
          ...
          $cv->send;
      }
  ;

  my $error = $cv->recv;
  die $error if $error;

  $ginger->save( $cookie_jar => $cookie_dat );

=head1 DESCRIPITION

This library provides a way to load/save cookie_jar. and provides a way to
exchanges a format between B<TTP::Cookies::*> and B<ANyEvent::HTTP>.

=head1 METHODS

=over 4

=item new

  $client = Ginger::Cookies->new(%options);

Creates a new Ginger::Cookies instance. %options can take the B<trait>,
B<file>. B<trait> is set to a B<HTTP::Cookies::*> instance, if it is not
specified. you can specify a B<HTTP::Cookies::*> instance or name.

=item load

  $client->load( $cookies_file );

Reads a information of cookies from $cookies_file. this format is able to
read by a HTTP::Cookies::* instance that is specified by trait paramater.

=item save

  $client->save( $cookie_jar_hashref );
  # or
  $client->save( $cookie_jar_hashref => $cookes_file );

Writes a information of cookies to $cookies_file. you can omit $cookie_file
if specified I<trait> at the time of created.
Required $cookie_jar_hashref. $cookie_jar_hashref is used in the context of
AnyEvent::HTTP.

=item cookie_jar

  $cookie_jar_hashref = $client->cookie_jar();

Return the cookie_jar that using the context of AnyEvent::HTTP. this is just
a HashRef.

=item set_cookie

  $client->set_cookie( $cookie_jar_hashref );

Set a information of cookies to Ginger::Cookies instance for save.

=back

=head1 SEE ALSO

L<HTTP::Cookies>, L<AnyEvent::HTTP>.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

