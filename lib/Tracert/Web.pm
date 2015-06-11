package Tracert::Web;
use strict;
use warnings;

use Carp ();
use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use DateTime;
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
use Net::DNS ();
use Web::Feed;

use Tracert::Exe;
use Tracert::DB;
use Tracert::Blog;

our $VERSION = '0.01';

=head1 NAME

Tracert::Web - The website of tracert.com

=cut

my $env;

my %RED = (
	'/linode' =>
		'http://www.linode.com/?r=cccf1376edd5c6f0b8eccb97e0741a1f24584e43',
	'/digitalocean' => 'https://www.digitalocean.com/?refcode=0d4cc75b3a74',

	'/index.html'     => '/',
	'/copyright.html' => '/copyright',
	'/privacy.html'   => '/privacy',
	'/tos.html'       => '/tos',
	'/faq.html'       => '/faq',
	'/resources.html' => '/resources',
	'/contact.html'   => '/contact',
	'/services.html'  => '/services',
	'/news.html'      => '/news',

	(
		map { $_ => '/resolver' }
			qw(
			/cgi-bin/resolver.pl
			/resolve_exe.html
			/resolver.html
			),
	),

	(
		map { $_ => '/traceroute' }
			qw(
			/trace.html
			/traceexplain.html
			/trace_exe.html
			/tracegw.html
			/tracesites.html
			/cgi-bin/trace.pl
			/cgi-bin/tracesites.pl

			),
	),
	(
		map { $_ => '/ping' }
			qw(
			/pingexplain.html
			/ping.html
			/ping_exe.html
			/pinggw.html
			/pingsites.html
			/cgi-bin/ping.pl
			/cgi-bin/pingsites.pl

			),
	),
);

sub run {
	my $root = root();

	my $app = sub {
		$env = shift;

		my $request   = Plack::Request->new($env);
		my $path_info = $request->path_info;

		if ( $path_info eq '/' ) {

			return template(
				'index',
				{
					title  => 'Tracert - running traceroute world wide',
					client => _client($env),

				}
			);
		}

		if ( $path_info eq '/news' ) {
			return serve_blog();
		}
		if ( $path_info eq '/atom' ) {
			return serve_blog_atom($env);
		}
		if ( $path_info eq '/sitemap.xml' ) {
			return sitemap( $env, $request );
		}
		if ( $path_info eq '/robots.txt' ) {
			my $url = $request->base;
			$url =~ s{/$}{};

			my $txt = <<"END_TXT";
Sitemap: $url/sitemap.xml
END_TXT
			return [ '200', [ 'Content-Type' => 'text/plain' ], [$txt], ];
		}

		if ( $path_info eq '/run' ) {
			return run_traceroute( $env, $request );
		}
		if ( $path_info eq '/gw-head' ) {
			return plain_template('gw_head');
		}

		if ( $path_info =~ m{^/(traceroute6|traceroute|ping6|ping)$} ) {
			return traceroute( $env, $request, $1 );
		}

		if ( $path_info =~ m{^/(looking-glass)$} ) {
			return list_sites( $env, $request, $1 );
		}

		if ( $path_info eq '/recent' ) {
			return recent();
		}

		if ( $path_info eq '/resolver' ) {
			return resolver($request);
		}

		if ( $path_info =~ m{^/\w+} ) {
			my $file_path = "$root/pages$path_info.txt";
			if ( -e $file_path ) {
				my @lines = path($file_path)->lines_utf8;

				my %data;
				while (@lines) {
					if ( $lines[0] =~ m{^=(\w+)\s+(.+?)\s*$} ) {
						$data{$1} = $2;
						shift @lines;
					}
					else {
						last;
					}
				}
				$data{content} = join "\n", @lines;
				return template( 'page', \%data );
			}
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
			path => qr{^/(images|js|css|fonts|favicon.ico|google419b25b06d9f4ffc.html)},
			root => "$root/static/";
		$app;
	};
}

sub recent {

#experimental feature, extermly stupid way to get most recent entries of the log
	my $root = root();
	my $filename = "$root/logs/" . strftime( '%Y-%m-%d.txt', gmtime() );
	my @lines;
	if ( open my $fh, '<', $filename ) {
		@lines = <$fh>;
		my $LIMIT = 20;
		if ( @lines > $LIMIT ) {
			splice( @lines, 0, -$LIMIT );
		}
	}
	my @entries;
	chomp @lines;
	foreach my $line (@lines) {
		my ( $timestamp, $action, $data ) = split /:/, $line, 3;
		$data = eval { from_json($data) };
		push @entries,
			{
			timestamp => $timestamp,
			action    => $action,
			%$data,
			};
	}
	return template( 'recent',
		{ events => \@entries, title => 'Recent requests' } );
}

sub save {
	my ( $action, $results ) = @_;
	my $root = root();
	mkdir "$root/logs";
	my $filename = "$root/logs/" . strftime( '%Y-%m-%d.txt', gmtime() );
	if ( open my $fh, '>>', $filename ) {
		say $fh join ':', time, $action, to_json $results;
		close $fh;
	}
}

sub resolver {
	my ($request) = @_;

	my %params;
	my $hostname = $request->param('arg');
	if ($hostname) {
		$params{hostname} = $hostname;
		my $res = Net::DNS::Resolver->new;
		for my $record (qw(A AAAA)) {
			$params{results}{"record_$record"} = [];
			my $query = $res->search( $hostname, $record );
			if ($query) {
				foreach my $rr ( $query->answer ) {
					if ( $rr->type eq $record ) {
						push @{ $params{results}{"record_$record"} },
							$rr->address;
					}
				}
			}
		}
		save( 'resolve', \%params );
	}

	$params{title} = 'Resolver gateway - Testing DNS resolving';
	return template( 'resolver', \%params );
}

sub run_traceroute {
	my ( $env, $request ) = @_;

	my $host = $request->param('host');
	my @gws  = $request->param('gw');
	if ( not $host ) {
		return [ '200', [ 'Content-Type' => 'text/html' ], ['Missing host'],
		];
	}
	if ( not @gws ) {
		return [
			'200', [ 'Content-Type' => 'text/html' ],
			['Missing gateways'],
		];
	}

	my %gws = map { $_ => 1 } @gws;

	my @gateways = grep { $gws{ $_->{id} } } _get_gateways($host);

	my $top_frame_height = 15;
	my $frame_height
		= int( 10 * ( 100 - $top_frame_height ) / scalar @gateways ) / 10;

	# "15%,42.5%,42.5%"
	my $rows = "$top_frame_height%," . join ',',
		( ("$frame_height%") x scalar @gateways );

	# TODO check if valid IP and/or valid hostname
	# TODO if it starts with http:// remove it before passing to clients.

	return plain_template( 'run',
		{ frames => \@gateways, host => $host, rows => $rows } );
}

sub _get_gateways {
	my ($host) = @_;
	my $data = Tracert::DB->new( root => root() )->load_data();
	return
		grep { $_->{status} eq 'SHOW' or $_->{status} eq 'ENABLE' }
		@{ $data->{gateways} };
}

sub list_sites {
	my ( $env, $request, $service ) = @_;

	my @gws
		= sort { lc $a->{country} cmp lc $b->{country} } _get_gateways('');
	return template(
		'sites',
		{
			title    => ucfirst($service) . ' from around the world',
			gateways => \@gws,
			service  => $service,
		}
	);
}

sub traceroute {
	my ( $env, $request, $service ) = @_;

	my $host = _client($env);

	#my ($out) = Tracert::Exe->trace( host => $host, lines => 5 );

	my @gws
		= sort { lc $a->{country} cmp lc $b->{country} } _get_gateways($host);
	return template(
		'traceroute',
		{
			title    => ucfirst($service) . ' from around the world',
			gateways => \@gws,
			service  => $service,
			host     => $host,

			#out   => $out,
		}
	);
}

sub _client {
	my ($env) = @_;

	my $request = Plack::Request->new($env);

	# these two extra env variables are passed by Nginx
	my $client
		= $env->{HTTP_X_REAL_IP}
		|| $env->{HTTP_X_FORWARDED_HOST}
		|| $request->remote_host
		|| $request->address;

	# let the developer see tracert.com in the box, not localhost
	return $client eq '127.0.0.1' ? 'tracert.com' : $client;
}

sub sitemap {
	my ( $env, $request ) = @_;

	my $now = strftime( '%Y-%m-%d.txt', gmtime() );

	my $blog = Tracert::Blog->new( dir => root() . '/pages' );
	$blog->collect;
	my @posts = reverse sort { $a->{timestamp} cmp $b->{timestamp} }
		grep { $_->{timestamp} } @{ $blog->posts };

	my @pages = map { { filename => $_, timestamp => $now, } }
		qw(traceroute ping resolver looking-glass traceroute6 ping6 resources help news);

	push @pages,
		map { { filename => $_->{path}, timestamp => $_->{timestamp} } }
		@posts;

	my $url = $request->base;
	$url =~ s{/$}{};

	my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>\n};
	$xml
		.= qq{<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n};
	foreach my $p (@pages) {
		$xml .= qq{  <url>\n};
		$xml .= qq{    <loc>$url/$p->{filename}</loc>\n};
		if ( $p->{timestamp} ) {
			$xml .= sprintf qq{    <lastmod>%s</lastmod>\n},
				substr( $p->{timestamp}, 0, 10 );
		}

		#$xml .= qq{    <changefreq>monthly</changefreq>\n};
		#$xml .= qq{    <priority>0.8</priority>\n};
		$xml .= qq{  </url>\n};
	}
	$xml .= qq{</urlset>\n};

	return [ '200', [ 'Content-Type' => 'application/xml' ], [$xml], ];

}

sub serve_blog_atom {
	my ($env) = @_;

	my $xml = '';

	my $request = Plack::Request->new($env);
	my $url     = $request->base;
	$url =~ s{/$}{};

	my $blog = Tracert::Blog->new( dir => root() . '/pages' );
	$blog->collect;
	my @posts = reverse sort { $a->{timestamp} cmp $b->{timestamp} }
		grep { $_->{timestamp} } @{ $blog->posts };

	my $ts = DateTime->now;
	my @entries;
	foreach my $p (@posts) {
		my %e;
		$e{title}   = $p->{title};
		$e{summary} = qq{<![CDATA[$p->{content}]]>};
		$e{updated} = $p->{timestamp};

		$e{link} = qq{$url/$p->{path}};

		$e{id} = $p->{link};

		#		$e{content} = qq{<![CDATA[$p->{abstract}]]>};
		push @entries, \%e;
	}

	my $pmf = Web::Feed->new(
		url     => $url,
		path    => 'atom',
		title   => 'Tracert news',
		updated => $ts,
		entries => \@entries,
		description =>
			'Tracert - Traceroute, Ping, Looking Glass, DNS name resolution and other network analyzis tools',
	);

	return [
		'200',
		[ 'Content-Type' => 'application/atom+xml' ],
		[ $pmf->atom ],
	];
}

sub serve_blog {

	my $blog = Tracert::Blog->new( dir => root() . '/pages' );
	$blog->collect;
	my @posts = reverse sort { $a->{timestamp} cmp $b->{timestamp} }
		grep { $_->{timestamp} } @{ $blog->posts };
	return template( 'blog', { posts => \@posts } );
}

sub plain_template {
	my ( $file, $vars ) = @_;
	my $root = root();

	my $tt = Template->new(
		INCLUDE_PATH => "$root/tt",
		INTERPOLATE  => 0,
		POST_CHOMP   => 1,
		EVAL_PERL    => 0,
		START_TAG    => '<%',
		END_TAG      => '%>',
	);
	my $out;
	$tt->process( "$file.tt", $vars, \$out )
		|| Carp::confess $tt->error();
	return [ '200', [ 'Content-Type' => 'text/html' ], [$out], ];
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

	if ( $ENV{DEV} ) {
		$vars->{timestamp} = '?' . time;
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

