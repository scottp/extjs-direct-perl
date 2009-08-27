#!/usr/bin/perl
use warnings;
use strict;
use RPC::ExtDirect;

my $config = {
	Profile => {
		Class => 'Demo',
		getBasicInfo => { params => 2 },
		getPhoneInfo => { params => 1 },
		getLocationInfo => { params => 1 },
		updateBasicInfo => { params => 2, formHandler => 1, },
		doTest => { params => 1 },
	},
};

# Create the object
my $ed = RPC::ExtDirect->new($config);

# Example using PATH_INFO for router or api request
if ($ENV{PATH_INFO} =~ /api/) {
	$ed->api();
}
else {
	$ed->router();
}

