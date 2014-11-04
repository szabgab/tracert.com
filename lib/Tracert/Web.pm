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
use Socket qw(inet_ntoa);
use Template;
use Time::Local qw(timegm);

use Tracert::Exe;

our $VERSION = '0.01';

=head1 NAME

Tracert::Web - The website of tracert.com

=cut

my $env;



my %RED = (
	'/index.html'        => '/',
	'/copyright.html'    => '/copyright',
	'/privacy.html'      => '/privacy',
	'/tos.html'          => '/tos',
	'/faq.html'          => '/faq',
	'/resources.html'    => '/resources',
	'/contact.html'       => '/contact',
	'/services.html'     => '/services',
	'/news.html'         => '/news',


map { $_ => '/resolver' } qw(
	/cgi-bin/resolver.pl
	/resolve_exe.html
	/resolver.html
),

	map { $_ => '/traceroute' } qw(
		/trace.html
		/traceexplain.html
	/trace_exe.html
	/tracegw.html
	/tracesites.html
	/cgi-bin/trace.pl
	/cgi-bin/tracesites.pl

	),

	map { $_ => '/ping' } qw(
	/pingexplain.html
	/ping.html
	/ping_exe.html
	/pinggw.html
	/pingsites.html
	/cgi-bin/ping.pl
	/cgi-bin/pingsites.pl

	),
);

sub run {
	my $root = root();

	my $app = sub {
		$env = shift;

		my $request   = Plack::Request->new($env);
		my $path_info = $request->path_info;

		# these two extra env variables are passed by Nginx
		my $client
			= $env->{HTTP_X_REAL_IP}
			|| $env->{HTTP_X_FORWARDED_HOST}
			|| $request->remote_host
			|| $request->address;

		if ( $path_info eq '/' ) {

			return template(
				'index',
				{
					title  => 'Tracert - running traceroute world wide',
					client => $client
				}
			);
		}

		
		if ( $path_info eq '/traceroute' ) {
			return traceroute($request, 'trace');
		}
		if ( $path_info eq '/ping' ) {
			return traceroute($request, 'ping');
		}
		if ( $path_info eq '/resolver' ) {
			return resolver($request);
		}

		my %STATIC = (
		'/copyright' => { title => 'Tracert copyright' },
		'/privacy' => { title => 'Tracert privacy policy' },
		'/tos'  => { title => 'Tracert Terms of Service' }, 
		'/faq' => { title => 'Tracert FAQ - Frequently Asked Questions' },
		'/resources' => { title => 'Other Resources' },
		'/contact'  => { title => 'Contact information' },
		'/services' => { title => 'Services' },
		'/news'     => { title => 'News' },
	);

		if ($STATIC{$path_info}) {
			return template( substr($path_info, 1), $STATIC{$path_info});
		}

		if ( $path_info =~ m{//} ) {
			$path_info =~ s{//+}{/}g;
			return redirect($path_info);
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

sub resolver {
	my ($request) = @_;

	my %params = ( title => 'Resolver gateway - Testing DNS resolving', );
	my $hostname = $request->param('arg');
	if ($hostname) {
		$params{hostname} = $hostname;
		my $packed = scalar gethostbyname $hostname;
		if ($packed) {
			my $ip = inet_ntoa($packed);
			if ($ip) {
				$params{ip} = $ip;
			}
		}
	}
	return template( 'resolver', \%params );
}

sub traceroute {
	my ($request, $service) = @_;

	my $host = $request->param('t');

	#my ($out) = Tracert::Exe->trace( host => $host, lines => 5 );

	my $data = load_data();
	my @gws = sort { $a->{country} cmp $b->{country} } @{ $data->{gateways} };
	return template(
		'traceroute',
		{
			title    => ($service eq 'trace' ? 'Traceroute' : 'Pint'),
			gateways => \@gws,
			service  => $service,

			#			host  => $host,
			#			out   => $out,
		}
	);
}

sub load_data {

	my $root = root();
	my $path = "$root/data/db.json";
	my $data = from_json path($path)->slurp_utf8;

	#die Dumper $data;
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

