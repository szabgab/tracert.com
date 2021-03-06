package Tracert;
use 5.010;
use Moo;
use Data::Dumper qw(Dumper);

use Tracert::DB;

has root => ( is => 'ro', required => 1 );

sub check_sites {
	my ($self) = @_;

	my $data = Tracert::DB->new( root => $self->root )->load_data();

	my %ids;

	#die Dumper $data;

	foreach my $gw ( @{ $data->{gateways} } ) {
		if ( $ids{ $gw->{id} } ) {
			warn "Duplicate ID '$gw->{id}'\n";
		}
		$ids{ $gw->{id} } = $gw;

		if ( $gw->{status} eq 'SHOW' ) {
			say "$gw->{access_type} $gw->{url} '$gw->{input}'";

			next;
		}

		say "Invalid status $gw->{status}";
	}

}

1;

