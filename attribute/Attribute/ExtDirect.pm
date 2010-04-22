package Attribute::ExtDirect;
use Attribute::Handlers;
use Exporter qw/import/;
@EXPORT = qw/ext_config/;

my $DEBUG = 0;

# Original Configuration & override during import
our $ext_config_data = {Methods => {}};
our $ext_config_name = '';
sub import2 {
	my ($class, $config) = @_;

	# Class name - passed in as config, else assume short version of class
	my $ext_config_name = $config->{Name} || $class;
	$ext_config_name =~ s/^.*:://g;

	$ext_config_data = {
		Class => $class,
	};
	
	# DEFAULT - before/afters
	#if (ref($config) eq "HASH") {
	#	# TODO - just copy for now, consider alternatives...
	#	$ext_config = $config;
	#}

	$ext_config_data{Methods} = {};

	return $class->SUPER::import();
}

# ======================================================================
# Exported 'ext_config' for all modules
sub ext_config {
	return {
		$ext_config_name => $ext_config_data
	};
}

# ======================================================================
# New attribute "ExtDirect"
sub UNIVERSAL::ExtDirect :ATTR(CODE) {
    my ($pack, $ref, $ref2, $att4, $data) = @_;
	my $name = *{$ref}{NAME};
    print STDERR "Package=$pack, Subname=$name, Number of parameters=$data\n" if ($DEBUG);
	$ext_config_data->{Methods}{$name} = {
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
