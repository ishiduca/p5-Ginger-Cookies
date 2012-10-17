# Ginger::Cookies

a tool of load/save of HTTP Cookie jars for AnyEvent::HTTP

## Usage

* load from *$HOME/Library/Cookies/Cookies.plist*
* save to *./Cookies/Cookies.dat*

```perl
use AnyEvent;
use AnyEvent::HTTP;
use Ginger::Cookies;

my $cookie_file = "$ENV{HOME}/Library/Cookies/Cookies.plist";
my $ginger = Ginger::Cookies->new(
    trait => 'HTTP::Cookies::Safari',
    file  => $cookie_file,
);
my $cookie_jar = $ginger->cookie_jar;

my $cv = AE::cv;
http_get 'http://hoge.to/check_loggedin',
    cookie_jar => $cookie_jar,
    sub {
        my(undef, $hdr) = @_;
        my $url = $hdr->{URL};
        if ($url eq 'http://hoge.to/myaccount') {
            ...
            $cb->send;
        } else {
            $cb->croak("! failed: $hdr->{Status} $hdr->{Reason} ($url)");
        }
    }
;

my $error = $cb->recv;

die $error if $error;

my $ginger2 = Ginger::Cookies->new;
$ginger2->save( $cookie_jar => "./Cookies/Cookie.dat");
```

## Method

### 1new(%args)


retrun a cookie_jar client.
this client can *load* a data of cookies form file and *save* a data.
a loading/save mechanism is borrowed form `$args{trait}`.

`$args{trait}` must be used a instance that is inherited *HTTP::Cookies*.

```perl
my $client = Ginger::Cookies->new(
    trait => HTTP::Cookies->new( file => $cookies_file )
);
```

or require a string that specify the module to be inheried *HTTP::Cookies*.

```perl
my $client = Ginger::Cookies->new(
    trait => "HTTP::Cookies",
    file  => $cookies_file,
);
```

### load( $cookies_file )

load a cookies from $cookies_file.

### cookie_jar

return a $cookie_jar(HashRef) that can be used by AnyEvent::HTTP.

```perl
my $cookie_jar = $client->cookie_jar;
```

### save( $cookie_jar => $cookies_file )

save a cookies to $cookies_file.


