package AttributeTest;
use Attribute::ExtDirect;

sub new {
	return bless {}, shift;
}

sub NowMe : ExtDirect(3) {
	my ($x, $y, $z) = @_;
	return ($x * $y * $z);
}

1;
