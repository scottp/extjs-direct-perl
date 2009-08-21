#!/usr/bin/perl
use warnings;
use strict;
# use CGI qw/:standard/;
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

my $data = _read_content();
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

print "Content-type: text/plain\n\n";
print to_json(\@results);

exit 0;

# HACK TO LOAD RAW DATA !
# 	Read the undecoded data !
#	NOTE:
#		Not sure if that is correct?
#		Shoudl we decode?
sub _read_content {
	my $length = $ENV{CONTENT_LENGTH};
	my $buf;
	read STDIN, $buf, $length;
	return from_json($buf);
}

