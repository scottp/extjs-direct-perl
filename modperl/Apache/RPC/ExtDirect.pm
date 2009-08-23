package Apache::RPC::ExtDirect;
use warnings;
use strict;
use version; our $VERSION = qv('0.0.3');
use JSON;
use mod_perl2 ;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK NOT_FOUND HTTP_MOVED_TEMPORARILY);
use Apache2::RequestUtil;
use Apache2::Request;
use Apache2::Log ;

# ======================================================================
# CONFIG AND DATA STORE
# ======================================================================
# Store configs by file name
our %configs = ();

# ======================================================================
# Load configuration file, and preload all classes & instantiate required 
# objects
# TODO: Make it optional, and have Apache load data on demand if required
# TODO: Document that you can do a postconfig or child init, depending
# on your instantiation requirements (e.g. if connecting to a DB you need
# to use Child init, if not, then you can do it pre-fork)
# ======================================================================
sub post_config {
	my ($conf_pool, $log_pool, $temp_pool, $s) = @_;
	#my $config = $s->dir_config('ExtDirect_Preload');
	# XXX HACK !
	my $config = "/home/ubuntu/4gw/extjs-direct-perl/modperl/config.pl";
	_preload($s, $config);
	return Apache2::Const::OK;
}

sub child_init {
	my ($self, $child_pool, $s) = @_;
	#my $config = $s->dir_config('ExtDirect_Preload');
	# XXX HACK !
	my $config = "/home/ubuntu/4gw/extjs-direct-perl/modperl/config.pl";
	_preload($s, $config);
	return Apache2::Const::OK;
}

sub _preload {
	my ($s, $config) = @_;
	$s->log->debug("ExtDirect: Child init");
	foreach my $f (split(/,/, $config)) {
		$s->log->debug("ExtDirect: Child init - $f");
		_config($f, $s);
	}
}

# ======================================================================
# HANDLER - Automatically support api and router URLs with one handler
# ======================================================================
sub handler {
	my ($r) = @_;
	my $uri = $r->path_info;
	if ($uri =~ /api/) {
		$r->log->debug("ExtDirect: handler -> api");
		return api($r);
	}
	else {
		$r->log->debug("ExtDirect: handler -> router");
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
	my $config = _config($r->dir_config("ConfigFile"), $r);

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
# ROUTER - Handle all incoming requrests
# ======================================================================
sub router {
	my ($r) = @_;

	my $config = _config($r->dir_config("ConfigFile"), $r);

	# XXX INPUTS?
	#	For now assume HTTP Post Data (not supporting separate fields yet, e.g. form post)
	#	Can be single entry - {...}
	#	or Multiple entry [{...},{...}]
	# XXX This is high risk - reading in data and parsing as JSON, likely to fail

	# Read raw input (can I just use $r->content ?)
	my $content = "";
	# TODO consider checking it is post ! (it must be)
	die "No post data" unless ($r->headers_in->{'Content-length'} > 0);
	$r->read($content,$r->headers_in->{'Content-length'});
	my $data = from_json($content);
	# Normalise into an array !
	if (ref($data) ne "ARRAY") { $data = [ $data ]; }

	# For each reqeust
	my @results;
	foreach my $request (@$data) {
		# TODO: Data security on inputs
		my $action = $request->{action};
		my $method = $request->{method};
		# TODO: Check number of arguments
		my $data = $request->{data};

		# If it exists ! (security issue)
		unless ($config->{$action}{Methods}{$method}) {
			die "BAD REQUEST - Invalid action/method - $action/$method";
		}

		$r->log->debug("ExtDirect: Executing $action/$method");

		# Security check - access control rules

		# Call the method (consider eval, capture errors etc)
		my $result;
		if ($config->{$action}{Instantiate}) {
			$result = $config->{$action}{Object}->$method(ref($data) eq "ARRAY" ? @$data : ());
		}
		else {
			my $class = $config->{$action}{Class} || $action;
			$result = $class->$method(ref($data) eq "ARRAY" ? @$data : ());
		}
		
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
	my ($file, $r) = @_;

	# Configuration file?
	#	TODO: Multiple configuration formats
	#		e.g. Direct Apache config
	#		Perl configuration
	#		Others, e.g. YAML
	#		OR Make sure this code can be overloaded !

	if (!exists($configs{$file})) {
		$r->log->debug("ExtDirect: Loading config from $file");
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
		if ($config->{$action}{Instantiate}) {
			$config->{$action}{Object} = $class->new($config->{$action}{Instantiate});
		}
	}
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Apache::RPC::ExtDirect - A backend server stack for the Ext JS 3.0 Ext.Direct framework

=head1 VERSION

This document describes IlodeAuth::Apache version 0.0.1

=head1 SYNOPSIS

	PerlModule Apache::RPC::ExtDirect

	# This
	<Location /data>
		SetHandler modperl
		PerlResponseHandler Apache::RPC::ExtDirect
	</Location>

	# OR
	<Location /data/api>
		SetHandler modperl
		PerlResponseHandler Apache::RPC::ExtDirect->api
	</Location>
	<Location /data/router>
		SetHandler modperl
		PerlResponseHandler Apache::RPC::ExtDirect->router
	</Location>

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
