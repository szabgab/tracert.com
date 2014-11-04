package Tracert::Exe;
use strict;
use warnings;

sub trace {
	my ( $class, $host ) = @_;

	my @exes = qw(/usr/sbin/traceroute /usr/bin/tracepath);
	my ($command) = grep { -x $_ } @exes;
	return 'No executable found' if not $command;

	my $out = '';
	if (
		$host !~ /\.\./
		and (  ( $host =~ /^(\d+\.\d+\.\d+\.\d+)$/ )
			or ( $host =~ /^([a-zA-Z0-9][a-zA-Z0-9\.\-_]*)$/ ) )
		)
	{
		$host = $1;    # unTaint
		eval {
			local $SIG{ALRM} = sub { die 'Timeout' };
			my $start = time;
			alarm(10);
			my $cnt = 5;
			if ( open my $ph, '-|', "$command $host" ) {
				while ( my $line = <$ph> ) {
					$out .= $line;
					last if $cnt-- < 0;
				}
			}
		};
		alarm(0);
		return $out;
	}
	else {
		return 'Invalid hostname';
	}

}

1;

