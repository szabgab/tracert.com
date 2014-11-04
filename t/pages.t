use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common qw(GET);
use Test::HTML::Tidy;

use t::lib::Test;

plan tests => 1;

use Tracert::Web;

my $tidy = html_tidy();

my $app = Tracert::Web->run;

subtest main => sub {
	plan tests => 2;

	test_psgi $app, sub {
		my $cb  = shift;
		my $res = $cb->( GET '/' );
		is $res->code, 200, 'code 200';
		my $html = $res->content;
		contains( $html, 'Run trace' );
	};
	}

