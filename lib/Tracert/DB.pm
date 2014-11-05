package Tracert::DB;
use Moo;

use JSON qw(from_json to_json);
use Path::Tiny qw(path);

has root => (is => 'ro', required => 1);

sub load_data {
	my ($self) = @_;

	my $root = $self->root;
	my $path = "$root/data/db.json";
	my $data = from_json path($path)->slurp_utf8;

	#die Dumper $data;
	return $data;
}


1;

