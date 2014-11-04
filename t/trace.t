use strict;
use warnings;

use Test::More;
plan tests => 2;

use Tracert::Exe;

{
	my $out = Tracert::Exe->trace('cnn.com;rm -rf');
	is $out, 'Invalid hostname';
}

{
	my $out = Tracert::Exe->trace('localhost');
	like $out,
		qr{^\s*1  localhost \(127.0.0.1\)  \d\.\d+ ms  \d\.\d+ ms  \d\.\d+ ms$},
		'localhost';
}

#{
#	my $out = Tracert::Exe->trace('localhost');
#	diag $out;
#}
#
