package Tracert;
use 5.010;
use Moo;
use Data::Dumper qw(Dumper);

use Tracert::DB;

has root => (is => 'ro', required => 1);


sub check_sites {
	my ($self) = @_;

	my $data = Tracert::DB->new(root => $self->root)->load_data();
	#die Dumper $data;

	foreach my $gw (@{ $data->{gateways} }) {
		if ($gw->{status} eq 'SHOW') {
			my $url = "$gw->{url}$gw->{path}";
			say "$gw->{access_type} $url '$gw->{input}'  '$gw->{extra_params}'";

			next;
		}

		say "Invalid status $gw->{status}";
	}

	
}


1;

