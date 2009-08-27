#!/usr/bin/perl
use warnings;
use strict;
use CGI qw/:standard :cgi-lib/;
use JSON;
use lib '.';
use Demo;

# ROUTER - the basics

# XXX Temporary API definition - this could be introspective, any format...
my $CONFIG = do "config.pl";

# INPUTS?
#	For now assume HTTP Post Data (not supporting separate fields yet)
#	Can be single entry - {...}
#	or Multiple entry [{...},{...}]

# ==============================================================================
# REQUEST DATA - Post data (not form encoded) or a single form post request
# ==============================================================================
my $data;
if (param('POSTDATA')) {
	$data = from_json(param('POSTDATA'));
}
else {
	# ext specific variables here...
	# 	extAction	Profile
	# 	extMethod	updateBasicInfo
	# 	extTID	8
	# 	extType	rpc
	# 	extUpload	false
	my $raw_data = Vars();
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
}

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
	unless ($CONFIG->{$action}{$method}) {
		die "BAD REQUEST - Invalid action/method - $action/$method";
	}

	# Security check - access control rules

	# Call the method (consider eval, capture errors etc)
	# my $class = $CONFIG->{$action}{class};
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

# TODO: Consider UTF-8
print header('text/plain');
print to_json(\@results);

exit 0;
