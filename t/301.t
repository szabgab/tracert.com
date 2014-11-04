use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common qw(GET);
use Test::HTML::Tidy;

use t::lib::Test;

use Tracert::Web;

my $tidy = html_tidy();

my $app = Tracert::Web->run;

# URL pairs. Given the first URL, sco should redirect to the second.
my @cases;

push @cases, map { [ $_ => '/ping' ] } qw(
	/ping_exe.html
	/pinggw.html
	/pingsites.html
	/cgi-bin/ping.pl
	/cgi-bin/pingsites.pl
);

push @cases, map { [ $_ => '/traceroute' ] } qw(
	/tracegw.html
	/tracesites.html
	/cgi-bin/trace.pl
	/cgi-bin/tracesites.pl
	/trace_exe.html

);

push @cases, map { [ $_ => '/' ] } qw(
	/index.html
);

push @cases, map { [ $_ => '/resolver' ] } qw(
	/cgi-bin/resolver.pl
	/resolve_exe.html
	/resolver.html
);

plan tests => 3 * @cases;

foreach my $c (@cases) {
	test_psgi $app, sub {
		my $cb  = shift;
		my $res = $cb->( GET $c->[0] );
		is $res->code, 301, "code 301 for $c->[0]";
		ok $res->is_redirect, "redirect $c->[0]";
		is $res->header('Location'), $c->[1], "Location for $c->[0]";
	};
}

