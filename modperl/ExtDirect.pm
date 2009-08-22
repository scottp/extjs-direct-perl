package ExtDirect;
# TODO: Use an apache name space, e.g. Apache2::ExtDirect
use warnings;
use strict;
use version; our $VERSION = qv('0.0.3');
use Carp;
use JSON;

# mod_perl
use mod_perl2 ;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK NOT_FOUND HTTP_MOVED_TEMPORARILY);
use URI::Escape;
use Apache2::RequestUtil;
use Apache2::Request;

# Store configs by file name
our %configs = ();

=head1 NOTES

Some configuration notes

# XXX should I use one handler with /api and /router

# This
<Location /data>
	SetHandler modperl
	PerlResponseHandler ExtDirect
</Location>

# OR
<Location /data/api>
	SetHandler modperl
	PerlResponseHandler ExtDirect->api
</Location>
<Location /data/router>
	SetHandler modperl
	PerlResponseHandler ExtDirect->router
</Location>

=cut

# ======================================================================
# Local data store
# ======================================================================
# Configuration - (XXX this should be per Location, currently only one)
my $config;

# ======================================================================
# Load configuration file, and preload all classes & instantiate required 
# objects
# TODO: Make it optional, and have Apache load data on demand if required
# ======================================================================
sub child_init {
	my ($child_pool, $s) = @_;
	return Apache2::Const::OK;
}

# ======================================================================
# HANDLER - Automatically support api and router URLs with one handler
# ======================================================================
sub handler {
	my ($r) = @_;
	my $uri = $r->path_info;
	if ($uri =~ /api/) {
		return api($r);
	}
	else {
		return router($r);
	}
}

# ======================================================================
# API - Return a Javascript definition of the Remote API from config
# ======================================================================
sub api {
	my ($r) = @_;

	# CONFIG ?
	# TODO change to _get - which would do config, init, cache etc
	my $config = _config($r);

	my $actions = {};
	foreach my $action (keys %$config) {
		# The methods...
		my @methods;
		foreach my $method (keys %{$config->{$action}{Methods}}) {
			push @methods, {
				name => $method,
				len => $config->{$action}{Methods}{$method}{params},
			};
		}
		$actions->{$action} = \@methods;
	}

	# TODO: Consider overload in config else fall back to this
	my $uri = $r->uri;
	if ($uri =~ /api/) {
		$uri =~ s/api/router/;
	}
	else {
		$uri =~ s|/$||;
		$uri .= '/router';
	}

	# NOTE: This is not JSON, it is actual Javascript being laoded ! Thus the "Ext.app... ="

	# XXX what type should this Javascript be output as?
	$r->content_type('text/plain');
	$r->rflush();

	$r->print(
		"Ext.app.REMOTING_API = "
			. to_json({
			url => $uri,
			type => 'remoting',
			actions => $actions,
		})
	);
	
	return Apache2::Const::OK;
}

# ======================================================================
# Router - Handle all incoming requrests
# ======================================================================
sub router {
	my ($r) = @_;

	my $config = _config($r);

	# INPUTS?
	#	For now assume HTTP Post Data (not supporting separate fields yet)
	#	Can be single entry - {...}
	#	or Multiple entry [{...},{...}]

	# XXX This is high risk - reading in data and parsing as JSON, likely to fail

	# Read raw input (can I just use $r->content ?)
	my $content = "";
	die "No post data" unless ($r->headers_in->{'Content-length'} > 0);
	$r->read($content,$r->headers_in->{'Content-length'});
	my $data = from_json($content);

	# Normalise into an array !
	if (ref($data) ne "ARRAY") {
		$data = [ $data ];
	}

	# For each reqeust
	my @results;
	foreach my $request (@$data) {
		# INPUT: {"action":"TestAction","method":"doEcho","data":["sample"],"type":"rpc","tid":2},
		# TODO: Data security on inputs
		my $action = $request->{action};
		my $method = $request->{method};
		# TODO: Check number of arguments
		my $data = $request->{data};

		# If it exists ! (security issue)
		unless ($config->{$action}{Methods}{$method}) {
			die "BAD REQUEST - Invalid action/method - $action/$method";
		}

		# Security check - access control rules

		# Call the method (consider eval, capture errors etc)
		my $class = $config->{$action}{Class} || $action;
		# TODO: Instead of instantiating the object, have that as an otion in the
		# config, including parameters to new
		# XXX Support instantiation
		my $result = $class->$method(ref($data) eq "ARRAY" ? @$data : ());
		
		# OUTPUT: {"type":"rpc","tid":2,"action":"TestAction","method":"doEcho","result":"sample"},
		push @results, {
			type => 'rpc',
			tid => $request->{tid},
			action => $action,
			method => $method,
			result => $result,
		};
	}

	$r->content_type('text/plain');
	$r->rflush();
	$r->print(to_json(\@results));
	return Apache2::Const::OK;
}

# ======================================================================
# Helpers
# ======================================================================

# Configuration - return the configuraiton
sub _config {
	my ($r) = @_;

	# Configuration file?
	#	TODO: Multiple configuration formats
	#		e.g. Direct Apache config
	#		Perl configuration
	my $file = $r->dir_config("ConfigFile");

	if (!exists($configs{$file})) {
		my $config = do $file;
		if ($@) { die "Failed to read config file $file - $@" }
		# _init if not already
		_init($config);
		# Cache file?
		$configs{$file} = $config;
	}
	return $configs{$file};
}

# Init the components based on the config input
# Call only once after a config file is loaded (consider caching)
sub _init {
	my ($config) = @_;
	
	foreach my $action (keys %$config) {
		# Load new class
		my $class = $config->{$action}{Class} || $action;
		eval "use $class;";
		if ($@) {
			# TODO - proper errors for Apache
			die "Unable to load $class - $@";
		}
		#if ($config->{$action}{Instantiate}) {
		#}
	}
}

1; # Magic true value required at end of module
__END__

=head1 NAME

IlodeAuth::Apache - [One line description of module's purpose here]

=head1 VERSION

This document describes IlodeAuth::Apache version 0.0.1

=head1 SYNOPSIS

	use ExtDirect;

=head1 DESCRIPTION

=head1 INTERFACE 

=head1 DIAGNOSTICS

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

IlodeAuth::Apache requires no configuration files or environment variables.


=head1 DEPENDENCIES

None.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

Scott Penrose  C<< <scott@cpan.org> >>

TODO

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, Scott Penrose C<< <scott@cpan.org> >>. All rights reserved.

TODO

=head1 DISCLAIMER OF WARRANTY

TODO
