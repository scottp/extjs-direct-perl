package Demo;
use JSON;

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
	return {
		success => JSON::false,
		errors => {
			email => 'Email already taken',
		},
	};
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

sub allowed {
	#if ( (time % 2) == 0) {
	#	die "Sorry... even time...";
	#}
	return 1;
}

sub clean {
	return 1;
}

sub getBasicInfo_test {
	return 1;
}

1;
