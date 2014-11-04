package Tracert::Web;
use strict;
use warnings;

use Carp ();
use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use File::Basename qw(dirname);
use HTTP::Tiny;
use JSON qw(from_json to_json);
use LWP::Simple qw(get);
use Path::Tiny qw(path);
use Plack::Builder;
use Plack::Response;
use Plack::Request;
use Pod::Simple::HTML;
use POSIX qw(strftime);
use Template;
use Time::Local qw(timegm);

our $VERSION = '0.01';

=head1 NAME

Tracert::Web - The website of tracert.com

=cut

my $env;

my %RD = map { $_ => 1 } qw(
	/trace_exe.html
	/ping_exe.html
	/pinggw.html
	/tracegw.html
	/tracesites.html
	/pingsites.html
	/cgi-bin/trace.pl
	/cgi-bin/ping.pl
	/cgi-bin/pingsites.pl
	/cgi-bin/tracesites.pl
	/index.html
);

#	'/pingexplain.html'      => '/ping.html',

my %RR = map { $_ => 1 } qw(
	/cgi-bin/resolver.pl
	/resolve_exe.html
	/resolver.html
);

my %RED = (
	'/trace.html'        => '/traceroute',
	'/traceexplain.html' => '/traceroute',
	'/copyright.html'    => '/copyright',
	'/privacy.html'      => '/privacy',
	'/tos.html'          => '/tos',
	'/faq.html'          => '/faq',
);

sub run {
	my $root = root();

	my $app = sub {
		$env = shift;

		my $request   = Plack::Request->new($env);
		my $path_info = $request->path_info;

		if ( $path_info eq '/' ) {
			my $client = $request->remote_host || $request->address;
			return template(
				'index',
				{
					title  => 'Tracert - running traceroutes',
					client => $client
				}
			);
		}
		if ( $path_info eq '/resolver' ) {
			return template( 'resolver',
				{ title => 'Resolver gateway - Testing DNS resolving' } );
		}

		if ( $path_info eq '/copyright' ) {
			return template( 'copyright', { title => 'TraceRT copyright' } );
		}

		if ( $path_info eq '/privacy' ) {
			return template( 'privacy',
				{ title => 'TraceRT privacy policy' } );
		}
		if ( $path_info eq '/tos' ) {
			return template( 'tos', { title => 'TraceRT Terms of Service' } );
		}
		if ( $path_info eq '/faq' ) {
			return template(
				'faq',
				{
					title => 'TraceRT FAQ - Frequently Asked Questions'
				}
			);
		}

		if ( $path_info =~ m{//} ) {
			$path_info =~ s{//+}{/}g;
			return redirect($path_info);
		}

		if ( $RD{$path_info} ) {
			return redirect('/');
		}
		if ( $RR{$path_info} ) {
			return redirect('/resolver');
		}
		if ( $RED{$path_info} ) {
			return redirect( $RED{$path_info} );
		}

		return not_found();
	};

	builder {
		enable 'Plack::Middleware::Static',
			path => qr{^/(favicon.ico|robots.txt)},
			root => "$root/static/";
		$app;
	};
}

sub template {
	my ( $file, $vars ) = @_;
	$vars //= {};
	Carp::confess 'Need to pass HASH-ref to template()'
		if ref $vars ne 'HASH';

	my $root = root();

	my $ga_file = "$root/config/google_analytics.txt";
	if ( -e $ga_file ) {
		$vars->{google_analytics} = path($ga_file)->slurp_utf8 // '';
	}

	my $as_file = "$root/config/adsense.txt";
	if ( -e $as_file ) {
		$vars->{adsense} = path($as_file)->slurp_utf8 // '';
	}

	#eval {
	#	$vars->{totals} = from_json path("$root/totals.json")->slurp_utf8;
	#};

	my $request = Plack::Request->new($env);

	#$vars->{query} //= $request->param('query');
	#$vars->{mode}  //= $request->param('mode');

	my $tt = Template->new(
		INCLUDE_PATH => "$root/tt",
		INTERPOLATE  => 0,
		POST_CHOMP   => 1,
		EVAL_PERL    => 0,
		START_TAG    => '<%',
		END_TAG      => '%>',
		PRE_PROCESS  => 'incl/header.tt',
		POST_PROCESS => 'incl/footer.tt',
	);
	my $out;
	$tt->process( "$file.tt", $vars, \$out )
		|| Carp::confess $tt->error();
	return [ '200', [ 'Content-Type' => 'text/html' ], [$out], ];
}

sub root {
	my $dir = dirname( dirname( dirname( abs_path(__FILE__) ) ) );
	$dir =~ s{blib/?$}{};
	return $dir;
}

sub redirect {
	my ($url) = @_;
	my $res = Plack::Response->new();
	$res->redirect( $url, 301 );
	return $res->finalize;
}

sub not_found {
	my $reply = template('404');
	return [ '404', [ 'Content-Type' => 'text/html' ], $reply->[2], ];
}

1;

