package XML::Generator;

use strict;
use vars qw/$VERSION $AUTOLOAD/;

package XML::Generator::overload;

use overload '""'   => sub { ${$_[0]} };
use overload '0+'   => sub { ${$_[0]} };
use overload 'bool' => sub { ${$_[0]} };
use overload 'eq'   => sub { ${$_[0]} eq $_[1] };

package XML::Generator;

$VERSION = 0.5;

sub AUTOLOAD {
  my($this, $first, $second, @rest) = @_;
  my $tag = $AUTOLOAD;
  $tag =~ s/.*:://;
  if ($tag eq 'new' && !ref($this)) {
    if (defined $first && defined $second) {
      $this = bless {$first => $second, @rest}, $this;
    } else {
      $this = bless {}, $this;
    }
    if (defined $this->{'namespace'}) {
      $this->{'namespace'} =~ s/:$//;
    }
    return $this;
  } 
  my($xml,$attr,$namespace);
  $namespace = $this->{'namespace'};
  if (ref $first eq 'HASH') {
    $attr = $first;
    unshift(@rest, $second) if defined $second;
  } elsif (ref $first eq 'ARRAY') {
    $namespace = join ':', @$first;
    if (ref $second eq 'HASH') {
      $attr = $second;
    } else {
      unshift(@rest, $second) if defined $second;
    }
  } elsif (defined $first) {
    unshift(@rest, $second) if defined $second;
    unshift(@rest, $first);
  }
  if ($this->{'escape'}) {
    if ($this->{'escape'} eq 'always') {
      if ($attr) {
        for my $a (keys %{$attr}) {
	  my $v = $attr->{$a};
	  $v =~ s/&/&amp;/g;
	  $v =~ s/</&lt;/g;
	  $v =~ s/>/&gt;/g;
	  $v =~ s/"/&quot;/g;
	  $attr->{$a} = $v;
	}
      }
      for (@rest) {
	unless (ref $_) {
	  s/&/&amp;/g;
	  s/</&lt;/g;
	  s/>/&gt;/g;
	}
      }
    } else {
      if ($attr) {
        for my $a (keys %{$attr}) {
	  my $v = $attr->{$a};
	  $v =~ s/([^\\]|^)&/$1&amp;/g;
	  $v =~ s/\\&/&/g;
	  $v =~ s/([^\\]|^)</$1&lt;/g;
	  $v =~ s/\\</</g;
	  $v =~ s/([^\\]|^)>/$1&gt;/g;
	  $v =~ s/\\>/>/g;
	  $v =~ s/([^\\]|^)"/$1&quot;/g;
	  $v =~ s/\\"/"/g;
	  $attr->{$a} = $v;
	}
      }
      for (@rest) {
	unless (ref $_) {
	  s/([^\\]|^)&/$1&amp;/g;
	  s/\\&/&/g;
	  s/([^\\]|^)</$1&lt;/g;
	  s/\\</</g;
	  s/([^\\]|^)>/$1&gt;/g;
	  s/\\>/>/g;
	}
      }
    }
  }
  $namespace .= ':' if $namespace;
  $xml = "<$namespace$tag";
  if ($attr) {
    $xml .= ' ';
    $xml .= join ' ', map {qq|$namespace$_="$attr->{$_}"|} keys %$attr;
  }
  if (@rest) {
    $xml .= '>';
    $xml .= join $, || '',@rest;
    $xml .= "</$namespace$tag>";
  } else {
    $xml .= ' />';
  }
  return bless \$xml, 'XML::Generator::overload';
}
1;
__END__

=head1 NAME

XML::Generator - Perl extension for generating XML

=head1 SYNOPSIS

  use XML::Generator;
  
  my $x = new XML::Generator;
  print $x->foo($x->bar({baz=>3}, $x->bam()),
		$x->bar([qux],"Hey there,\n", "world"));
  __END__
  # The above would yield:
  <foo><bar baz="3"><bam/></bar><qux:bar>Hey there,
world</qux:bar></foo>

  

=head1 DESCRIPTION

XML::Generator is a simple module to help in the generation of XML.
Basically, you create an XML::Generator object and then call a method
for each tag, supplying the contents of that tag as parameters.

You can use a hash ref as the first parameter if the tag should include
atributes.  An array ref can be supplied as the first argument to indicate
a namespace for the element and the attributes (the elements of the array
are concatenated with ':').  A global namespace can be set for the
XML::Generator object by supplying a

	'namespace' => 'HTML'

argument to the constructor.  E.g.,

	my $html = new XML::Generator 'namespace' => 'HTML';
	print $html->font({face => 'Arial'});

would yield

	<HTML:font HTML:face="Arial" />

If you want to specify a namespace as well as attributes, you can make the
second argument a hash ref.  If you do it the other way around, the array ref
will simply get stringified and included as part of the content of the tag.
If an XML::Generator object has a namespace set, and a namespace is also
supplied to the tag, the supplied namespace overrides the default.

The contents and the values of each attribute have the illegal XML
characters escaped if the XML::Generator object was constructed with an
'escape' argument.  If the value of the escape argument is 'always', then
&, < and > (and " within attribute values) will be converted into the
corresponding XML entity.  If the value is any other true value, then the
escaping will be turned off if the character in question is preceded by a
backslash.  So, for example,

	my $a = new XML::Generator 'escape' => 'always';
	my $b = new XML::Generator 'escape' => 'true';
	print $a->foo('<', $b->bar('3 \> 4'), '\&', '>');

would yield

	<foo>&lt;<bar>3 \> 4</bar>\&amp;&gt;</foo>

The XML is returned as a string (actually, it's a blessed reference to a
scalar which stringifies, numifies and boolifies into the scalar itself,
but you don't have to worry about that).

A valid XML document must consist of a single tag at the top level, but
this module does nothing to enforce that.

=head1 BUGS

Tags which the lexer won't interpret as subroutines are very cumbersome to
deal with.  E.g., "some-tag".  You can do this:

    $x = new XML::Generator;
    {
      no strict 'refs';
      print *{(ref $x).'::some-tag'}->($x, { 'attr' => 42 }, 3);
    }

Which yields:

    <some-tag attr="42">3</some-tag>

But I wouldn't recommend that if you value your sanity.

=head1 AUTHOR

Benjamin Holzman, bholzman@earthlink.net

=head1 SEE ALSO

=over 4

=item Perl-XML FAQ

http://www.perlxml.com/faq/perl-xml-faq.html

=item The XML::Writer module

$CPAN/modules/by-authors/id/DMEGG/XML-Writer-0.2.tar.gz

=back

=cut
