#!/usr/bin/perl -w

use Test;

BEGIN { $| = 1; plan tests => 77; }

use XML::Generator ();
ok(1);

my $x = XML::Generator->new();
ok($x);

my $xml = $x->foo();
ok($xml, '<foo />');

$xml = $x->bar(42);
ok($xml, '<bar>42</bar>');

$xml = $x->baz({'foo'=>3});
ok($xml, '<baz foo="3" />');

$xml = $x->bam({'bar'=>42},$x->foo(),"qux");
ok($xml, '<bam bar="42"><foo />qux</bam>');

$xml = $x->new(3);
ok($xml, '<new>3</new>');

$xml = $x->import(3);
ok($xml, '<import>3</import>');

$xml = $x->foo(['baz']);
ok($xml, '<foo xmlns="baz" />');

$xml = $x->foo(['baz','bam']);
ok($xml, '<baz:foo xmlns:baz="bam" />');

$xml = $x->foo(['baz'],{'bar'=>42},3);
ok($xml, '<foo xmlns="baz" bar="42">3</foo>');

$xml = $x->foo(['baz','bam'],{'bar'=>42},3);
ok($xml, '<baz:foo xmlns:baz="bam" baz:bar="42">3</baz:foo>');

$xml = $x->foo({'id' => 4}, 3, 5);
ok($xml, '<foo id="4">35</foo>');

$xml = $x->foo({'id' => 4}, 0, 5);
ok($xml, '<foo id="4">05</foo>');

$xml = $x->foo({'id' => 4}, 3, 0);
ok($xml, '<foo id="4">30</foo>');

my $foo_bar = "foo-bar";
$xml = $x->$foo_bar(42);
ok($xml, '<foo-bar>42</foo-bar>');

$x = new XML::Generator 'escape' => 'always';

$xml = $x->foo({'bar' => '4"4'}, '<&>"\<', \"<>");
ok($xml, '<foo bar="4&quot;4">&lt;&amp;&gt;"\&lt;<></foo>');

$x = new XML::Generator 'escape' => 'true';

$xml = $x->foo({'bar' => '4\"4'}, '<&>"\<', \"&& 6 < 5");
ok($xml, '<foo bar="4"4">&lt;&amp;&gt;"<&& 6 < 5</foo>');

$x = new XML::Generator 'namespace' => ['A'];

$xml = $x->foo({'bar' => 42}, $x->bar(['B'], {'bar' => 54}));
ok($xml, '<foo xmlns="A" bar="42"><bar xmlns="B" bar="54" /></foo>');

$x = new XML::Generator 'conformance' => 'strict';
$xml = $x->xmldecl();
ok($xml, qq(<?xml version="1.0" standalone="yes"?>\n));

$xml = $x->xmlcmnt("test");
ok($xml, '<!-- test -->');

$x = new XML::Generator 'conformance' => 'strict',
			'version' => '1.1',
			'encoding' => 'iso-8859-2';
$xml = $x->xmldecl();
ok($xml, qq(<?xml version="1.1" encoding="iso-8859-2" standalone="yes"?>\n));

$xml = $x->xmldecl(version => undef, encoding => undef, standalone => undef);
ok($xml, qq(<?xml?>\n));

$xml = $x->xmldecl(version => '1.0', encoding => 'utf8', standalone => 'no');
ok($xml, qq(<?xml version="1.0" encoding="utf8" standalone="no"?>\n));

$xml = $x->xmlpi("target", "option" => "value");
ok($xml, '<?target option="value"?>');

eval {
  $x->xmlfoo();
};
ok($@ =~ /names beginning with 'xml' are reserved by the W3C/, 1);

eval {
  my $t = "42";
  $x->$t();
};
ok($@ =~ /name \[42] may not begin with a number/, 1);

eval {
  my $t = "g:";
  $x->$t();
};
ok($@ =~ /name \[g:] contains illegal character\(s\)/, 1);

$xml = $x->foo(['bar'], {'baz:foo' => 'qux', 'fob' => 'gux'});
ok($xml eq '<foo xmlns="bar" baz:foo="qux" fob="gux" />' ||
   $xml eq '<foo xmlns="bar" fob="gux" baz:foo="qux" />', 1, $xml);

$xml = $x->foo(['bar' => 'bam'], {'baz:foo' => 'qux', 'fob' => 'gux'});
ok($xml eq '<bar:foo xmlns:bar="bam" baz:foo="qux" bar:fob="gux" />' ||
   $xml eq '<bar:foo xmlns:bar="bam" bar:fob="gux" baz:foo="qux" />', 1, $xml);

$x = new XML::Generator;
$xml = $x->xml();
ok($xml, '<xml />');

$x = new XML::Generator 'conformance' => 'strict',
			'dtd' => [ 'foo', 'SYSTEM', '"http://foo.com/foo"' ];
$xml = $x->xmldecl();
ok($xml,
'<?xml version="1.0" standalone="no"?>
<!DOCTYPE foo SYSTEM "http://foo.com/foo">
');

$xml = $x->xmlcdata("test");
ok($xml, '<![CDATA[test]]>');

$x = new XML::Generator 'pretty' => 2, 'conformance' => 'strict';
$xml = $x->foo($x->bar());
ok($xml,
'<foo>
  <bar />
</foo>');

$xml = $x->foo($x->xmlcdata("bar"), $x->xmlpi("baz"));
ok($xml, '<foo><![CDATA[bar]]><?baz?></foo>');

$x = new XML::Generator 'conformance' => 'strict';
$xml = $x->foo(42);
$xml = $x->xml($xml);
ok($xml,
'<?xml version="1.0" standalone="yes"?>
<foo>42</foo>');

eval {
  $x->xml();
};
ok($@ =~ /usage/, 1);

eval {
  $x->xml(3);
};
ok($@ =~ /arguments to xml/, 1);

eval {
  $xml = $x->bar($xml);
};
ok($@ =~ /cannot embed/, 1);

$x = new XML::Generator 'pretty' => 2;
$xml = $x->foo($x->bar($x->baz()));
ok($xml,
'<foo>
  <bar>
    <baz />
  </bar>
</foo>');

$xml = $x->foo("\n<bar />");
ok($xml,
'<foo>
<bar /></foo>');

$x = new XML::Generator 'empty' => 'close';
$xml = $x->foo();
ok($xml, '<foo></foo>');

$x = new XML::Generator 'empty' => 'ignore';
$xml = $x->foo();
ok($xml, '<foo>');

eval {
  $x = new XML::Generator 'empty' => 'ignore', 'conformance' => 'strict';
};
ok($@ =~ /not allowed/, 1);

$x = new XML::Generator 'conformance' => 'strict';
$xml = $x->foo();
$cmnt = $x->xmlcmnt("comment");
$pi = $x->xmlpi("foo");
$xml = $x->xml($cmnt, $xml, $pi);
ok($xml, '<?xml version="1.0" standalone="yes"?>
<!-- comment --><foo /><?foo?>');

$x = new XML::Generator 'empty' => 'compact';
$xml = $x->foo();
ok($xml, '<foo/>');

$x = new XML::Generator 'empty' => 'args';
$xml = $x->foo(1);
ok($xml, '<foo>1</foo>');

$xml = $x->foo('');
ok($xml, '<foo></foo>');

$xml = $x->foo();
ok($xml, '<foo />');

$xml = $x->foo(undef);
ok($xml, '<foo />');

$x = XML::Generator->new(escape => 'always,high-bit');
$xml = $x->foo("<\242>");
ok($xml, '<foo>&lt;&#162;&gt;</foo>');

# check :options
$x = XML::Generator->new(':standard');
$xml = $x->foo('<', $x->xmlcmnt('c'));
ok($xml, '<foo>&lt;<!-- c --></foo>');

$x = XML::Generator->new(':pretty');
$xml = $x->foo('<', $x->bar($x->xmlcmnt('c')));
ok($xml, '<foo>&lt;
  <bar>
    <!-- c -->
  </bar>
</foo>');

$x = XML::Generator->new(':strict', escape => 'high-bit');
$xml = $x->foo("\\<\242", $x->xmlpi('g'));
ok($xml, '<foo><&#162;<?g?></foo>');

{ my $w; local $SIG{__WARN__} = sub { $w .= $_[0] };
  $x = XML::Generator->new(':import');
  ok($w =~ /Useless use of/, 1); $w = '';

  $x = XML::Generator->new(':noimport');
  ok($w =~ /Useless use of/, 1); $w = '';

  $x = XML::Generator->new(':stacked');
  ok($w =~ /Useless use of/, 1);
}

# test AUTOLOAD
package Test1;

use XML::Generator;

::ok(foo(), '<foo />');

package Test2;

use XML::Generator ':pretty';

::ok(foo(bar()), '<foo>
  <bar />
</foo>');

package Test3;

sub AUTOLOAD {
  return "foo" if our $AUTOLOAD =~ /bar/;
  return;
}

use XML::Generator;

::ok(barnyard(), 'foo');
::ok(foo(), undef);

package Test4;

use XML::Generator qw(:noimport);

$xml = undef;
eval {
  $xml = barnyard();
};
::ok($xml, undef);

package Test5;

sub AUTOLOAD {
  return "foo" if our $AUTOLOAD =~ /bar/;
  return;
}

use XML::Generator qw(:noimport);

::ok(barnyard(), "foo");
::ok(foo(), undef);

package Test6;

sub AUTOLOAD {
  return "foo" if our $AUTOLOAD =~ /bar/;
  return;
}

use XML::Generator qw(:import);

::ok(barnyard(), '<barnyard />');
::ok(foo(), '<foo />');

package Test7;

sub AUTOLOAD {
  return "foo" if our $AUTOLOAD =~ /bar/;
  return;
}

use XML::Generator qw(:stacked);

::ok(barnyard(), 'foo');
::ok(foo(), '<foo />');
::ok(foo(barnyard()), '<foo>foo</foo>');

# misc

package main;

$x = XML::Generator->new(':strict', allowed_xml_tags => ['xmlfoo']);
$xml = $x->widget(['wru' => 'http://www.widgets-r-us.com/xml/'],
		  {id => 123}, $x->contents([undef]));
ok($xml, '<wru:widget xmlns:wru="http://www.widgets-r-us.com/xml/" wru:id="123">'.
         '<contents xmlns="" />'.
         '</wru:widget>');


$xml = $x->xmlfoo('biznatch');
ok($xml, '<xmlfoo>biznatch</xmlfoo>');

$xml = $x->xmlcmnt('--');
ok($xml, '<!-- &#45;&#45; -->');

$A = XML::Generator->new(namespace => ['A']);
$B = XML::Generator->new(namespace => ['B' => 'bee']);
$xml = $A->foo($B->bar($A->baz()));
ok($xml, '<foo xmlns:B="bee" xmlns="A"><B:bar><baz /></B:bar></foo>');

$xml = $A->foo($A->bar($B->baz()));
ok($xml, '<foo xmlns:B="bee" xmlns="A"><bar><B:baz /></bar></foo>');

$xml = $A->foo($B->bar($B->baz()));
ok($xml, '<foo xmlns:B="bee" xmlns="A"><B:bar><B:baz /></B:bar></foo>');

$C = XML::Generator->new(namespace => [undef]);
$xml = $A->foo($C->bar($B->baz()));
ok($xml, '<foo xmlns:B="bee" xmlns="A"><bar xmlns=""><B:baz /></bar></foo>');

$D = XML::Generator->new();
$xml = $D->foo(['A'],$D->bar([undef],$D->baz(['B'=>'bee'])));
ok($xml, '<foo xmlns:B="bee" xmlns="A"><bar xmlns=""><B:baz /></bar></foo>');
