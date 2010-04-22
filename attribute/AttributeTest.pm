package AttributeTest;
use Attribute::ExtDirect {
	Test => 1,
	Fred => 'none',
};

sub calc : ExtDirect(3) {
	my ($x, $y, $z) = @_;
	return ($x * $y * $z);
}

1;
