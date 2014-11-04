package Tracert::Exe;
use strict;
use warnings;

sub trace {
	my ( $class, %params ) = @_;

	my $timeout = $params{timeout} || 10;

	my @exes = qw(/usr/sbin/traceroute /usr/bin/tracepath);
	my ($command) = grep { -x $_ } @exes;
	return 'No executable found' if not $command;

	my $out = '';
	if (
		$params{host} !~ /\.\./
		and (  ( $params{host} =~ /^(\d+\.\d+\.\d+\.\d+)$/ )
			or ( $params{host} =~ /^([a-zA-Z0-9][a-zA-Z0-9\.\-_]*)$/ ) )
		)
	{
		my $host      = $1;    # unTaint
		my $cnt_lines = 0;

		#local $SIG{__DIE__} = 'IGNORE';

		#eval {
		#	local $SIG{ALRM} = sub { die 'Timeout' };
		my $start = time;

		#	alarm($timeout);
		if ( open my $ph, '-|', "$command $host 2>&1" ) {
			while ( my $line = <$ph> ) {
				$out .= $line;
				$cnt_lines++;
				last if $params{lines} and $cnt_lines > $params{lines};
			}
			close $ph;
		}

		#};
		#alarm(0);
		return $out;
	}
	else {
		return "Invalid hostname: '$params{host}'";
	}

}

1;

