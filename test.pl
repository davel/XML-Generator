# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..6\n"; }
END {print "not ok 1\n" unless $loaded;}
use XML::Generator;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $x = new XML::Generator or print "not ";
print "ok 2\n";

my $xml = $x->foo();
$xml eq '<foo/>' or print "not ";
print "ok 3\n";

$xml = $x->bar(42);
$xml eq '<bar>42</bar>' or print "not ";
print "ok 4\n";

$xml = $x->baz({'foo'=>3});
$xml eq '<baz foo="3"/>' or print "not ";
print "ok 5\n";

$xml = $x->bam({'bar'=>42},$x->foo(),"qux");
$xml eq '<bam bar="42"><foo/>qux</bam>' or print "not ";
print "ok 6\n";
