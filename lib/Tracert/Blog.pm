package Tracert::Blog;
use Moose;
use Path::Tiny qw(path);

has dir => ( is => 'ro', required => 1 );
has posts => ( is => 'rw' );

sub collect {
	my ($self) = @_;

	my @posts;

	my $dir   = $self->dir;
	my @files = glob "$dir/*.txt";
	foreach my $f (@files) {
		push @posts, $self->read_file( substr( $f, length($dir) + 1, -4 ) );
	}
	$self->posts( \@posts );
	return scalar @posts;
}

sub read_file {
	my ( $self, $file ) = @_;

	my $dir = $self->dir;

	my @lines = path("$dir/$file.txt")->lines_utf8;
	my %post  = (
		content => '',
		path    => $file,
	);
	for my $line (@lines) {
		if ( $line =~ /^=(\w+)\s+(.*?)\s*$/ ) {
			$post{$1} = $2;
			next;
		}
		$post{content} .= $line;
	}

	return \%post;
}

no Moose;
__PACKAGE__->meta->make_immutable;

