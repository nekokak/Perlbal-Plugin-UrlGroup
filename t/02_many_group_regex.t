use strict;
use warnings;
use lib './lib';
use Perlbal::Test;
use Perlbal::Test::WebServer;
use Perlbal::Test::WebClient;
use Test::Declare;
use Test::TCP;

my %hosts = (
    'nekokak.intra'   => +{ },
    '*.nekokak.intra'   => +{ },
);

plan tests => scalar(keys %hosts) * 3 * 2;

# create tmp web server docroot path
my @jobs = qw/app app_s1 app_static/;
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
        $service_name .= "_$job";
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
    $service_name .= '_app';
    
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
    GROUP_REGEX ^/app_s1\$ = _s1

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
my @request_path = qw/app app_s1 static.gif/;
for my $host (keys %hosts) {
    for my $path (@request_path) {
        (my $request_host = $host) =~ s/\*/wildcard/;
        my $hoge = $wc->request({
            method  => "PUT",
            content => $path,
            host    => $request_host,
        }, $path);
    }
}

# do test test test!
describe 'Perlbal::Plugin::UrlGroupのテスト' => run {
    for my $host (keys %hosts) {
        for my $path (@request_path) {
            test "$host" => run {
                (my $request_host = $host) =~ s/\*/wildcard/;
                my $res = $wc->request({ host => $request_host}, $path);
                ok $res;
                is $res->content, $path;
            };
        }
    }
};

