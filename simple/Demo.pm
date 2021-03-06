package Demo;
use JSON;

sub new {
	my ($class) = @_;
	return bless {}, ref($class) || $class;
}

sub suburb {
	return "test suburb";
}

sub list {
	return ['a','b','c'];
}

sub add {
	return 1;
}
sub delete {
	return 1;
}
sub update {
	return 1;
}

sub getBasicInfo {
	# result":{"success":true,"data":{"foo":"bar","name":"Aaron Conran","company":"Ext JS, LLC","email":"aaron@extjs.com"}}
	return {
		success => JSON::true,
		data => {
			name => 'Scott Penrose',
			company => 'Rainbow house development',
			email => 'scottp@dd.com.au',
		},
	};
}

sub getPhoneInfo {
	return {};
}

sub getLocationInfo {
	return {};
}

sub updateBasicInfo {
	my ($class, $in) = @_;
	use Data::Dumper;
	print STDERR "updateBasicInfo received - " . Dumper($in) . "\n";
	return 1;
}

sub doEcho {
	my ($class, $in) = @_;
	return $in;
}

sub doTest {
	my ($class, $in) = @_;
	if ($in =~ /cott/) {
		return "You can not use 'Scott' in your name";
	}
	return JSON::true;
}

1;
