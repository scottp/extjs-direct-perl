#!/usr/bin/perl
use warnings;
use strict;
#use CGI qw/:standard/;
use JSON;
use Config::Any;

sub new {
	my ($class, $config) = @_;
	croak "Must provide a config hash" unless (ref($config) eq "HASH");
	return bless {
		config => $config,
	}, ref($class) || $class;
}

sub api {
	my ($this) = @_;

	my $actions = {};
	foreach my $action (keys %{$this->{config}}) {
		# The methods...
		my @methods;
		foreach my $method (keys %{$this->{config}{$action}}) {
			next if ($method eq "Class");
			push @methods, {
				name => $method,
				len => $this->{config}{$action}{$method}{params},
			};
		}
		$actions->{$action} = \@methods;
	}

	my $url = $ENV{SCRIPT_NAME};
	$url =~ s/api/router/;

	# NOTE: This is not JSON, it is actual Javascript being laoded ! Thus the "Ext.app... ="
	# XXX Support for format=json !
	print header(-type => 'text/javascript');
	print "Ext.app.REMOTING_API = ";
	print to_json({
		url => $url,
		type => 'remoting',
		actions => $actions,
	});
}

sub router {
	my ($this) = @_;

	# INPUTS?
	#	For now assume HTTP Post Data (not supporting separate fields yet)
	#	Can be single entry - {...}
	#	or Multiple entry [{...},{...}]

	# Hack to read form data (not via CGI)
	my $buf;
	read STDIN, $buf, $ENV{CONTENT_LENGTH};
	my $data from_json($buf);
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
		unless ($this->{config}{$action}{$method}) {
			die "BAD REQUEST - Invalid action/method - $action/$method";
		}

		# Security check - access control rules

		# Call the method (consider eval, capture errors etc)
		my $class = "Demo";
		# TODO: Instead of instantiating the object, have that as an otion in the
		# config, including parameters to new
		my $obj = $class->new();
		my $result = $obj->$method(ref($data) eq "ARRAY" ? @$data : ());
		
		# OUTPUT: {"type":"rpc","tid":2,"action":"TestAction","method":"doEcho","result":"sample"},
		push @results, {
			type => 'rpc',
			tid => $request->{tid},
			action => $action,
			method => $method,
			result => $result,
		};
		
	}

	print "Content-type: application/json\n\n";
	print to_json(\@results);
}

1;
