package Apache::RPC::ExtDirect;
use warnings;
use strict;
use version; our $VERSION = qv('0.0.5');
use mod_perl2 ;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK NOT_FOUND HTTP_MOVED_TEMPORARILY);
use Apache2::RequestUtil;
use Apache2::Request;
use Apache2::Log ;
use JSON;
use CGI;
use Config::Any;

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
		next if ($action eq 'DEFAULT');
		# The methods...
		my @methods;
		foreach my $method (keys %{$config->{$action}{Methods}}) {
			push @methods, {
				name => $method,
				len => $config->{$action}{Methods}{$method}{params},
				$config->{$action}{Methods}{$method}{formHandler} ? (formHandler => JSON::true) : (),
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
	my $q = new CGI;
	if ($q->param('format') && ($q->param('format') eq 'json')) {
		$r->content_type('application/json');
		$r->rflush();
		$r->print(to_json({
			url => $uri,
			type => 'remoting',
			actions => $actions,
		}));
	}
	else {
		$r->content_type('text/javascript');
		$r->rflush();
		$r->print(
			"Ext.app.REMOTING_API = " . to_json({
				url => $uri,
				type => 'remoting',
				actions => $actions,
			})
		);
	}
	
	return Apache2::Const::OK;
}

# ======================================================================
# ROUTER - Handle all incoming requrests
# ======================================================================
sub router {
	my ($r) = @_;

	my $config = _config($r->dir_config("ConfigFile"), $r);

	my $type = "JSON";
	my $data;
	my $q = new CGI;
	if ($q->param('POSTDATA')) {
		# Read JSON from unformatted post data
		$data = from_json($q->param('POSTDATA'));
		if (ref($data) ne "ARRAY") { $data = [ $data ]; }
	}
	else {
		$type = "FORM";
		# Parse post data and normalise as per JSON version
		my $raw_data = $q->Vars();
		$data = [
			{
				action => $raw_data->{extAction},
				method => $raw_data->{extMethod},
				tid => $raw_data->{extTID},
				type => $raw_data->{extType},
				upload => $raw_data->{extUpload},
				# TODO - remove ext[A-Z] entries above from list
				data => [$raw_data],
			}
		];
		# TODO - check for upload file !
	}

	# DEFAULT/before
	_run($obj, $config->{DEFAULT}{before}, "Before DEFAULT");

	# For each reqeust
	my @results;
	foreach my $request (@$data) {
		# TODO: Data security on inputs
		my $action = $request->{action};
		my $method = $request->{method};
		# TODO: Check number of arguments
		my $data = $request->{data};

		# If it exists ! (security issue)
		if (!$config->{$action} || ($action eq "DEFAULT")) {
			die "BAD REQUEST - Invalid action - $action";
		}
		unless ($config->{$action}{Methods}{$method}) {
			die "BAD REQUEST - Invalid action/method - $action/$method";
		}

		$r->log->debug("ExtDirect: Executing $action/$method");

		# TODO Security check - access control rules

		# Call the method (consider eval, capture errors etc)
		my $obj;
		if ($config->{$action}{Instantiate}) {
			$obj = $config->{$action}{Object};
		}
		else {
			$obj = $config->{$action}{Class} || $action;
		}
		
		# TODO "before" method
		_run($obj, $config->{$action}{before}, "Before $action");
		_run($obj, $config->{$action}{Methods}{$method}{before}, "Before $action/$method");

		# Run the actiual code
		my $result = $obj->$method(ref($data) eq "ARRAY" ? @$data : ());

		# TODO "after" method
		_run($obj, $config->{$action}{after}, "After $action");
		_run($obj, $config->{$action}{Methods}{$method}{after}, "After $action/$method");

		# TODO - Debugging information
		# 	type = 'exception'
		# 	message = Message which helps the developer identify what error occurred on the server-side
		# 	where = Message which tells the developer where the error occurred on the server-side.

		# OUTPUT: {"type":"rpc","tid":2,"action":"TestAction","method":"doEcho","result":"sample"},
		push @results, {
			type => 'rpc',
			tid => $request->{tid},
			action => $action,
			method => $method,
			result => $result,
		};
	}

	# DEFAULT/after
	_run($obj, $config->{DEFAULT}{after}, "After DEFAULT");

	# Return JSON or textarea wrapped HTML of JSON data.
	if ($type eq "UPLOAD") {
		# NOTE: HTML Format (single request - array? single entry? or just result section?
		# XXX This is not tested - and may need to encode quotes
		$r->print(
			'<html><body><textarea>'
			. to_json(\@results)
			. '</textarea></body></html>'
		);
	}
	else {
		# TODO: Review correct mime type for return
		$r->content_type('application/json');
		$r->print(to_json(\@results));
	}
	return Apache2::Const::OK;
}

# ======================================================================
# Helpers
# ======================================================================

# Run code - scalar, code or method
sub _run {
	my ($obj, $req, $info) = @_;
	if (ref($req) eq "SCALAR") {
		eval $$req;
		if ($@) {
			die "Failed on $info - $@";
		}
	}
	elsif (ref($req) eq "CODE") {
		eval $req->($obj);
		if ($@) {
			die "Failed on $info - $@";
		}
	}
	elsif (length($req) > 0) {
		eval $obj->$req();
		if ($@) {
			die "Failed on $info - $@";
		}
	}
}

# Configuration - return the configuraiton
sub _config {
	my ($file, $r) = @_;
	if (!exists($configs{$file})) {
		$r->log->debug("ExtDirect: Loading config from $file");
		my $config;
	
		# Load from a perl module (primative - consider fix !)
		if ($file =~ /::/) {
			# XXX what about just a load?
			$config = eval qq{
				use $file;
				return $file} . qq{->config();
			};
			if ($@) { die "Failed to read config file $file - $@" }
		}

		# Load from a file
		else {
			$config = eval {
				my $cfg = Config::Any->load_files({files => [$file], use_ext => 1,});
				$cfg->[0]->{$file};
			};
			if ($@) { die "Failed to read config file $file - $@" }
		}
		_init($config);
		$configs{$file} = $config;
	}
	return $configs{$file};
}

# Init the components based on the config input
# NOTE: Call only once after a config file is loaded
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

Apache::RPC::ExtDirect - A backend server stack for the Ext JS 3.0 Ext.Direct framework (ALPHA)

=head1 VERSION

This document describes IlodeAuth::Apache version 0.0.1

=head1 SYNOPSIS

	# ======================================================================
	# Basic Configuration
	# ======================================================================

	PerlModule Apache::RPC::ExtDirect
	<Location /data>
		SetHandler modperl
		PerlResponseHandler Apache::RPC::ExtDirect
		PerlSetVar ConfigFile /full/path/to/config.pl
	</Location>


	# ======================================================================
	# Advanced Configuration
	# ======================================================================
	
	# Load modules after config, but before fork
	PerlModule Apache::RPC::ExtDirect
	PerlPostConfigHandler Apache::RPC::ExtDirect::post_config
	PerlSetVar ExtDirect_Preload /full/path/to/config.pl,/another/config.pl
	# (or after fork) PerlChildInitHandler Apache::RPC::ExtDirect::child_init

	<Location /data/api>
		SetHandler modperl
		PerlResponseHandler Apache::RPC::ExtDirect::api
		PerlSetVar ConfigFile /full/path/to/config.pl
	</Location>

	<Location /data/router>
		SetHandler modperl
		PerlResponseHandler Apache::RPC::ExtDirect::router
		PerlSetVar ConfigFile /full/path/to/config.pl
	</Location>

=head1 DESCRIPTION

Apache::RPC::ExtDirect is a full implementation of the Ext.Direct server side
stack. It has the ability to: pre-load all necessary modules and configuration
files at start up time; instantiate objects; generate the Javascript API
(configuration); and route to the configured class.

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

Apache::RPC::ExtDirect requires no configuration files or environment variables.

=head1 DEPENDENCIES

Apache2, CGI, JSON and more...

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

=head1 DISCLAIMER OF WARRANTY

TODO
