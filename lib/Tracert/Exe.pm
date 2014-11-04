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

		my $start = time;

		#	alarm($timeout);
		if ( open my $ph, '-|', "$command $host 2>&1" ) {
			my $err;
			while (1) {
				my $line;
				eval {
					local $SIG{ALRM} = sub { die 'Timeout' };
					$line = <$ph>;
					alarm(0);
					1;
				} or do {
					$err = $@;
					alarm(0);
				};

				if ( defined $line ) {
					$out .= $line;
				}
				if ($err) {
					$out = "\n$err\n";
					last;
				}
				last if not defined $line;
				if ( time - $start > $timeout ) {
					$out .= "\nTimeout\n";
					last;
				}
				$cnt_lines++;
				if ( $params{lines} and $cnt_lines > $params{lines} ) {
					$out .= "\nMax lines reached\n";
					last;
				}
			}
			close $ph;
		}

		return $out;
	}
	else {
		return "Invalid hostname: '$params{host}'";
	}

}

1;

