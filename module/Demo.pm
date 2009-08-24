package Demo;
use JSON;

sub getBasicInfo {
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
