use Attribute::ExtDirect;
use AttributeTest;

print "End of the file\n";
my $o = AttributeTest->new();
print $o->NowMe(1,2,3) . "\n";

$o->ext_config();

1;
