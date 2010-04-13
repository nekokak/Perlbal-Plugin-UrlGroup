use strict;
use warnings;
use lib './lib';
use Perlbal::Test;
use Perlbal::Test::WebServer;
use Perlbal::Test::WebClient;
use Test::More;
use Test::TCP;

my %hosts = (
    'nekokak.intra'   => +{ },
    '*.nekokak.intra' => +{ },
    'kak.intra'       => +{ },
);

# create tmp web server docroot path
my @jobs = qw/app static/;
for my $host (keys %hosts) {
    for my $job (@jobs) {
        $hosts{$host}->{$job}->{dir} = tempdir();
    }
}

# create perlbal host SERVICE
my $service = '';
for my $host (keys %hosts) {
    for my $job (@jobs) {
        (my $service_name = $host) =~ s/[\.-]/_/g;
        $service_name .= "_$job" if $job eq 'static';
        $service_name =~ s/\*/wildcard/ if $service_name =~ /\*/;
        $service .= qq{
            CREATE SERVICE $service_name
                SET role          = web_server
                SET docroot       = $hosts{$host}->{$job}->{dir}
                SET enable_put    = 1
                SET enable_delete = 1
            ENABLE $service_name

        };
    }
}

# create perlba GROUP setting
my $listen_service_group = '';
for my $host (keys %hosts) {
    (my $service_name = $host) =~ s/[\.-]/_/g;
    $service_name =~ s/\*/wildcard/ if $service_name =~ /\*/;

    $listen_service_group .= qq{
        GROUP $host = $service_name
    };
}

my $port = Test::TCP::empty_port;

my $conf = qq{
LOAD UrlGroup

$service

CREATE SERVICE http_server
    SET listen          = 127.0.0.1:$port
    SET role            = selector
    SET plugins         = UrlGroup
    GROUP_REGEX \.(jpg|gif|png|js|css|swf)\$ = _static

$listen_service_group
ENABLE http_server

};

# start perlbal
Perlbal::Test::start_server($conf) or die qq{can't start testing perlbal.\n};

# create perlbal test client
my $wc = Perlbal::Test::WebClient->new;
$wc->server("127.0.0.1:$port");
$wc->keepalive(1);
$wc->http_version('1.0');

# put host data
my @request_path = qw/app static.gif/;
for my $host (keys %hosts) {
    for my $path (@request_path) {
        $wc->request({
            method  => "PUT",
            content => $host,
            host    => $host,
        }, $path);
    }
}

# do test test test!
subtest 'do test' => sub {
    for my $host (keys %hosts) {
        for my $path (@request_path) {
            (my $request_host = $host) =~ s/\*/wildcard/;
            my $res = $wc->request({ host => $request_host}, $path);
            ok $res;
            is $res->content, $host;
        }
    }
    done_testing;
};

done_testing;

