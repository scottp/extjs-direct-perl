#!/usr/bin/perl
use warnings;
use strict;
use CGI qw/:standard/;
use JSON;

# API - return the API definition

# XXX Temporary API definition - this could be introspective, any format...
my $CONFIG = do "config.pl";

my $actions = {};
foreach my $class (keys %$CONFIG) {
	# The methods...
	my @methods;
	foreach my $method (keys %{$CONFIG->{$class}}) {
		push @methods, {
			name => $method,
			len => $CONFIG->{$class}{$method}{params},
			$CONFIG->{$class}{$method}{formHandler} ? (formHandler => JSON::true) : (),
		};
	}
	$actions->{$class} = \@methods;
}

my $url = $ENV{SCRIPT_NAME};
$url =~ s/api/router/;

# NOTE: This is not JSON, it is actual Javascript being laoded ! Thus the "Ext.app... ="
if (param('format') && (param('format') eq 'json')) {
	print header(-type => 'application/json');
	print to_json({
		url => $url,
		type => 'remoting',
		actions => $actions,
	});
}
else {
	print header(-type => 'text/javascript');
	print "Ext.app.REMOTING_API = ";
	print to_json({
		url => $url,
		type => 'remoting',
		actions => $actions,
	});
}

exit 0;
