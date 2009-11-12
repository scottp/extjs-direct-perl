package Attribute::ExtDirect;
use Attribute::Handlers;
use base qw/Exporter/;
@EXPORT = qw/ext_config/;

# ======================================================================
# XXX Export the "ext_config" sub
our $ext_config = {
	Class => '.',
	Methods => {},
};
sub ext_config {
	use Data::Dumper;
	print Dumper($ext_config);
}

# ======================================================================
sub UNIVERSAL::ExtDirect :ATTR(CODE) {
	#my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
	#print STDERR "Package=$packate; Symbol=$symbol; Ref=$referent; Attr=$attr; Data=$data\n";
    my ($pack, $ref, $ref2, $att4, $data) = @_;
	my $name = *{$ref}{NAME};
    print STDERR "Package=$pack, Subname=$name, Number of parameters=$data\n";
	$ext_config->{Methods}{$name} = {
		params => $data,
	};
}

=head1 NAME

Attribute::ExtDirect - An easy way to configure your class

=head1 DESCRIPTION

Attribute::ExtDirect allows you to use attributes to define which methods would
normally be exported to an ExtDirect module. Currently it supports the
configuration required for Apache::RPC::ExtDirect (a mod_perl2 implementation).

=head1 SYNOPSIS

Create your package

	package Demo::Export;
	use Attribute::ExtDirect;
	sub calc : ExtDirect(3) {
		my ($x, $y, $z) = @_;
		return $x * $y * $z;
	}
	1;

Then in Apache add the configuration

	PerlModule Apache::RPC::ExtDirect
	<Location /direct/demo>
		SetHandler modperl
		PerlResponseHandler Apache::RPC::ExtDirect
		PerlSetVar ConfigFile Demo::Export
	</Locaiton>

=cut

1;
