use strict;
use warnings;

use Test::More;

plan skip_all => 'Temporarily skip all the traceroute tests';
__END__
plan tests => 3;

use Tracert::Exe;

{
	my $out = Tracert::Exe->trace( host => 'cnn.com;rm -rf' );
	is $out, q{Invalid hostname: 'cnn.com;rm -rf'};
}

{
	my $out = Tracert::Exe->trace( host => 'localhost' );
	like $out,
		qr{^\s*1  localhost \(127.0.0.1\)  \d\.\d+ ms  \d\.\d+ ms  \d\.\d+ ms$}m,
		'localhost';
	like $out,
		qr{^traceroute to localhost \(127.0.0.1\), 64 hops max, 52 byte packets$}m,
		'banner';
}

{
	#my $out = Tracert::Exe->trace(host => 'tracert.com');
	my $out = Tracert::Exe->trace( host => 'cnn.com', timeout => 2 );
	diag $out;
}

{
	#my $out = Tracert::Exe->trace(host => 'tracert.com');
	my $out
		= Tracert::Exe->trace( host => 'cnn.com', timeout => 20, lines => 3 );
	diag $out;
}
{
	#my $out = Tracert::Exe->trace(host => 'tracert.com');
	my $out = Tracert::Exe->trace(
		host    => 'cnn.com',
		timeout => 20,
		lines   => 15
	);
	diag $out;
}

