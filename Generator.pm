package XML::Generator;

use strict;
use Carp;
use vars qw/$VERSION $AUTOLOAD %xmltags @allowed_options/;
use constant PERL_VERSION => $];

$VERSION = 0.7;

=head1 NAME

XML::Generator - Perl extension for generating XML

=head1 SYNOPSIS

  use XML::Generator;
  
  my $x = XML::Generator->new('escape' => 'always',
                              'conformance' => 'strict'
                             );
  print $x->foo($x->bar({baz=>3}, $x->bam()),
		$x->bar(['qux'],"Hey there,\n", "world"));
  __END__

  # The above would yield:
  <foo><bar baz="3"><bam /></bar><qux:bar>Hey there,
world</qux:bar></foo>

=head1 DESCRIPTION

In general, once you have an XML::Generator object (which will actually
be blessed into the XML::Generator::auto package), you call methods on
that object for each XML tag you wish to generate.  Say you want to
generate this XML:

	<person>
	  <name>Bob</name>
	  <age>34</age>
	  <job>Accountant</job>
	</person>

Here's a snippet of code that does the job, complete with pretty-printing:

	use XML::Generator;
	my $gen = XML::Generator->new('escape' => 'always', 'pretty' => 2);
	my $xml = $gen->person(
		    $gen->name("Bob"),
		    $gen->age(34),
		    $gen->job("Accountant"));

The only problem with this is if you want to use a tag name that Perl's
lexer won't understand as a method name, such as "shoe-size".  Fortunately,
since you can always call methods as variable names, there's a simple
work-around:

	my $shoe_size = "shoe-size";
	$xml = $gen->$shoe_size("12 1/2");

Which correctly generates:

	<shoe-size>12 1/2</shoe-size>

You can use a hash ref as the first parameter if the tag should include
atributes.  An array ref can be supplied as the first argument to indicate
a namespace for the element and the attributes (the elements of the array
are concatenated with ':').  Under strict conformance, however, you are
only allowed one namespace component.

If you want to specify a namespace as well as attributes, you can make the
second argument a hash ref.  If you do it the other way around, the array ref
will simply get stringified and included as part of the content of the tag.
If an XML::Generator object has a namespace set, and a namespace is also
supplied to the tag, the supplied namespace overrides the default.

Here's an example to show how the attribute and namespace parameters work:

	$xml = $gen->account({'type' => 'checking', 'id' => '34758'},
		 $gen->open(['transaction'], 2000),
		 $gen->deposit(['transaction'], {'date' => '1999.04.03'},
			       1500));

This generates:

  <account type="checking" id="34578">
    <transaction:open>2000</transaction:open>
    <transaction:deposit transaction:date="1999.04.03">1500</transaction:deposit>
  </account>

=head1 CONSTRUCTOR

XML::Generator-E<gt>new( OPTIONS );

The following options are available:

=head2 namespace

The value of this option is used as the global default namespace.
For example,

	my $html = XML::Generator->new('namespace' => 'HTML');
	print $html->font({face => 'Arial'}, "Hello, there");

would yield

	<HTML:font HTML:face="Arial">Hello, there</HTML:font>

=head2 escape

The contents and the values of each attribute have the illegal XML
characters escaped if this option is supplied.  If the value is 'always',
then &, < and > (and " within attribute values) will be converted into the
corresponding XML entity.  If the value is any other true value, then the
escaping will be turned off if the character in question is preceded by a
backslash.  So, for example,

	my $a = XML::Generator->new('escape' => 'always');
	my $b = XML::Generator->new('escape' => 'true');
	print $a->foo('<', $b->bar('3 \> 4'), '\&', '>');

would yield

	<foo>&lt;<bar>3 > 4</bar>\&amp;&gt;</foo>

=head2 pretty

To have nice pretty printing of the output XML (great for config files
that you might also want to edit by hand), pass an integer for the
number of spaces per level of indenting, eg.

       my $gen = XML::Generator->new('pretty' => 2);
        print $gen->foo($gen->bar('baz'),
                       $gen->qux({'tricky' => 'no'}, 'quux')
                       );

would yield

       <foo>
         <bar>baz</bar>
         <qux tricky="no">quux</qux>
       </foo>

=head2 conformance

If the value of this option is 'strict', a number of syntactic
checks are performed to ensure that generated XML conforms to the
formal XML specification.  In addition, since entity names beginning
with 'xml' are reserved by the W3C, inclusion of this option enables
several special tag names; xmlpi, xmlcmnt, xmldecl and xmlcdata, to allow
generation of processing instructions, comments, XML declarations and
character data sections, respectively.

See L<"XML CONFORMANCE"> and L<"SPECIAL TAGS"> for more information.

=cut

## Alllow only these options:
# Only the options allowed by this list are entered into the object.
# If no value is provided, the value will be set to '' (empty string)

@allowed_options = qw(
  conformance
  dtd
  encoding
  escape
  namespace
  pretty
  version
);

sub new {
  my ($class, %args) = @_;
  my %options = map { $_ => ($args{$_} || '') } @allowed_options;
  if ($options{'dtd'}) {
    $options{'dtdtree'} = parse_dtd($options{'dtd'});
  }
  return bless \%options, 'XML::Generator::auto';
}

sub tag {
  my ($this, $tag, @args) = @_;
  my ($xml, $attr, $namespace);

  if ($this->{'conformance'} eq 'strict') {
    ck_syntax($tag);
  }

  $namespace = $this->{'namespace'} || '';

  # check for supplied namespace
  if (ref $args[0] eq 'ARRAY') {
    my $names = shift @args;
    if ($this->{'conformance'} eq 'strict' &&
	@$names > 1) {
      croak "only one namespace component allowed";
    }
    $namespace = join ':', @$names;
  }

  # Normalize namespace
  $namespace =~ s/:?$/:/ if $namespace;

  # check for supplied attributes
  if (ref $args[0] eq 'HASH') {
    $attr = shift @args;
  }

  # Deal with escaping if required
  if ($this->{'escape'}) {
    my $always = $this->{'escape'} eq 'always';  # boolean: always quote
    if ($attr) {
      foreach my $key (keys %{$attr}) {
        escape($attr->{$key}, 1, $always);
      }
    }
    for (@args) {
      escape($_, 0, $always) unless  # don't quote subobjects
	UNIVERSAL::isa($_, 'XML::Generator::overload');
    }
  }

  # generate the XML
  $xml = "<$namespace$tag";

  if ($attr) {
    while (my($k, $v) = each %$attr) {
      if ($this->{'conformance'} eq 'strict') {
	# allow supplied namespace in attribute names
	if ($k =~ s/^([^:]+)://) {
	  ck_syntax($k);
	  $k = "$1:$k";
	} else {
	  ck_syntax($k);
	  $k = "$namespace$k";
	}
      } else {
	if ($k !~ /^[^:]+:/) {
	  $k = "$namespace$k";
	}
      }
      $xml .= qq{ $k="$v"};
    }
  }

  if (@args) {
    $xml .= '>';
    if ($this->{'pretty'}) {
      my $prettyend = '';
      my $spaces = " " x $this->{'pretty'};
      foreach my $arg (@args) {
        if (UNIVERSAL::isa($arg, 'XML::Generator::overload')) {
          $xml .= "\n$spaces";
          $prettyend = "\n";
          $arg =~ s/\n/\n$spaces/egs;
        }
        $xml .= "$arg";
      }
      $xml .= $prettyend;
    } else {
      $xml .= join $, || '', @args;
    }
    $xml .= "</$namespace$tag>";
  } else {
    $xml .= ' />';
  }

  return bless \$xml, 'XML::Generator::overload';
}

=head1 XML CONFORMANCE

When the 'conformance' => 'strict' option is supplied, a number of
syntactic checks are enabled.  All entity and attribute names are
checked to conform to the XML specification, which states that they
must begin with either an alphabetic character or an underscore and
may then consist of any number of alphanumerics, underscores, periods
or hyphens.  Alphabetic and alphanumeric are interpreted according to
the current locale if 'use locale' is in effect and according to the
Unicode standard for Perl versions >= 5.6.  Furthermore, entity or
attribute names are not allowed to begin with 'xml' (in any case),
although a number of special tags beginning with 'xml' are allowed
(see L<"SPECIAL TAGS">).

In addition, only one namespace component will be allowed when strict
conformance is in effect, and attribute names can be given a specific
namespace, which will override both the default namespace and the tag-
specific namespace.  For example,

	my $gen = XML::Generator->new('conformance' => 'strict',
				      'namespace'   => 'foo');
	my $xml = $gen->bar({ 'a' => 1 },
		    $gen->baz(['bam'], { 'b' => 2, 'name:c' => 3 }));

will generate:

	<foo:bar foo:a="1">
	  <bam:baz bam:b="2" name:c="3" />
	</foo:bar>

=head1 SPECIAL TAGS

The following special tags are available:

=head2 xmlpi

Processing instruction; first argument is target, remaining arguments
are attribute, value pairs.  Attribute names are syntax checked, values
are escaped.

=head2 xmlcmnt

Comment.  Arguments are concatenated and placed inside <!-- ... --> comment
delimiters.  Any occurences of '--' in the concatenated arguments are
converted to '-&#45;'

=head2 xmldecl

XML Declaration.

=head2 xmlcdata

Character data section; arguments are concatenated and placed inside
<![CDATA[ ... ]]> character data section delimiters.  Any occurences of
']]>' in the concatenated arguments are converted to ']]&gt;'.

=cut

%xmltags = (

  "xmlpi" =>
    sub {
      my($this) = shift;
      my $xml;
      my $tgt  = shift;
      ck_syntax($tgt);

      $xml = "<?$tgt";
      if (@_) {
	my %atts = @_;
	while (my($k, $v) = each %atts) {
	  ck_syntax($k);
	  escape($v, 1, $this->{'escape'} eq 'always');
	  $xml .= qq{ $k="$v"};
	}
      }
      $xml .= "?>";

      return bless \$xml, 'XML::Generator::overload';
    },

  "xmlcmnt" =>
    sub {
      my($this) = shift;
      my $xml;
  
      $xml = join '', @_;

      # double dashes are illegal; change them to '-&#45;'
      $xml =~ s/--/-&#45;/g;

      $xml = "<!-- $xml -->";

      return bless \$xml, 'XML::Generator::overload';

    },

  "xmldecl" => 
    sub {
      my($this) = shift;
      my $xml;

      my $version = qq{ version="}.($this->{'version'} || '1.0').qq{"};

      # there's no explicit support for encodings yet, but at the
      # least we can know to put it in the declaration
      my $encoding = $this->{'encoding'}    ?
	qq{ encoding="$this->{'encoding'}"} : "";

      # similarly, although we don't do anything with DTDs yet, we
      # recognize a 'dtd' => [ ... ] option to the constructor, and
      # use it to create a <!DOCTYPE ...> and to indicate that this
      # document can't stand alone.
      my $standalone = qq{ standalone="}.($this->{'dtd'} ? "no" : "yes").qq{"};
      my $doctype    = $this->{'dtd'}                          ?
	qq{\n<!DOCTYPE }.(join ' ', @{ $this->{'dtd'} }).qq{>} : "";

      $xml = "<?xml$version$encoding$standalone?>$doctype";

      return bless \$xml, 'XML::Generator::overload';
    },

  "xmlcdata" =>
    sub {
      my($this) = shift;
      my $xml;

      $xml = join '', @_;

      # ]]> is not allowed; change it to ]]&gt;
      $xml =~ s/]]>/]]&gt;/g;

      $xml = "<![CDATA[$xml]]>";

      return bless \$xml, 'XML::Generator::overload';
    },
);

# Collect all escaping into one place
sub escape ($$$) {
  # $_[0] is the argument, $_[1] is the quote " flag, is the 'always' flag
  if ($_[2]) {
    $_[0] =~ s/&/&amp;/g;  # & first of course
    $_[0] =~ s/</&lt;/g;
    $_[0] =~ s/>/&gt;/g;
    $_[0] =~ s/"/&quot;/g if $_[1]; 
  } else {
    $_[0] =~ s/([^\\]|^)&/$1&amp;/g;
    $_[0] =~ s/\\&/&/g;
    $_[0] =~ s/([^\\]|^)</$1&lt;/g;
    $_[0] =~ s/\\</</g;
    $_[0] =~ s/([^\\]|^)>/$1&gt;/g;
    $_[0] =~ s/\\>/>/g;
    $_[0] =~ s/([^\\]|^)"/$1&quot;/g if $_[1];
    $_[0] =~ s/\\"/"/g if $_[1];
  } 
}

# verify syntax of supplied name; croak if it's not valid.
# rules: 1. name must begin with a letter or an underscore
#        2. name may contain any number of letters, numbers, hyphens,
#           periods or underscores
#        3. name cannot begin with "xml" in any case
sub ck_syntax {
  my($name) = @_;
  if (PERL_VERSION >= 5.6) {
    unless ($name =~ /^[\p{IsAlpha}_][\p{IsAlnum}\-\.]*$/) {
      if ($name =~ /^\p{IsDigit}/) {
	croak "name [$name] may not begin with a number";
      }
      croak "name [$name] contains illegal character(s)";
    }
  } else {
    # use \w and \d so that everything works under "use locale"
    if ($name =~ /^\w[\w\-\.]*$/) {
      if ($name =~ /^\d/) {
	croak "name [$name] may not begin with a number";
      }
    } else {
      croak "name [$name] contains illegal character(s)";
    }
  }
  if ($name =~ /^xml/i) {
    croak "names beginning with 'xml' are reserved by the W3C";
  }
}

my %DTDs;
my $DTD;

sub parse_dtd {
  my($dtd) = @_;

  my($root, $type, $name, $uri);
  unless (ref $dtd eq "ARRAY") {
    croak "dtd must be supplied as an array ref";
  }
  ($root, $type) = @{$dtd}[0,1];
  if ($type eq 'PUBLIC') {
    ($name, $uri) = @{$dtd}[2,3];
  } elsif ($type eq 'SYSTEM') {
    $uri = $dtd->[2];
  } else {
    croak "unknown dtd type [$type]";
  }
  return $DTDs{$uri} if $DTDs{$uri};

  my $dtd_text = get_dtd($uri);

# parse DTD into $DTD (not implemented yet)

  return $DTDs{$uri} = $DTD;
}

sub get_dtd {
  my($uri) = @_;
  return;
}

#########################################
# Objects are blessed into this auto namespace
# for convenient AUTOLOAD usage.
package XML::Generator::auto;

use vars qw/$AUTOLOAD/;

sub AUTOLOAD {
  my($this) = shift;
  my $tag = $AUTOLOAD;
  $tag =~ s/.*:://;
  # first check for special tags
  if ($this->{'conformance'} eq 'strict' &&
      $XML::Generator::xmltags{$tag}) {
      return $XML::Generator::xmltags{$tag}->($this, @_);
  }
  return XML::Generator::tag($this, $tag, @_);
}

package XML::Generator::overload;

use overload '""'   => sub { ${$_[0]} };
use overload '0+'   => sub { ${$_[0]} };
use overload 'bool' => sub { ${$_[0]} };
use overload 'eq'   => sub { ${$_[0]} eq $_[1] };

1;
__END__

=head1 AUTHORS

Benjamin Holzman, bholzman@earthlink.net

Bron Gondwana, perlcode@brong.net

=head1 SEE ALSO

=over 4

=item Perl-XML FAQ

http://www.perlxml.com/faq/perl-xml-faq.html

=item The XML::Writer module

$CPAN/modules/by-authors/id/DMEGG/XML-Writer-0.4.tar.gz

=item The XML::Handler::YAWriter module

$CPAN/modules/by-authors/id/KRAEHE/XML-Handler-YAWriter-0.15.tar.gz

=back

=cut
