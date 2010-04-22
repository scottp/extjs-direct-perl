use Attribute::ExtDirect;
use AttributeTest;

print "End of the file\n";
# my $o = AttributeTest->new();
print AttributeTest::calc(1,2,3) . "\n";

use Data::Dumper;
print Dumper(AttributeTest::ext_config());

1;
