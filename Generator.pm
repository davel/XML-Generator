package XML::Generator;

use strict;
use vars qw/$VERSION $AUTOLOAD/;

$VERSION = 0.4;

sub AUTOLOAD {
  my($this, $first, $second, @rest) = @_;
  my $tag = $AUTOLOAD;
  $tag =~ s/.*:://;
  if ($tag eq 'new' && !ref($this)) {
    return bless {$first => $second, @rest}, $this;
  }
  my($xml,$attr);
  if (ref $first eq 'HASH') {
    $attr = $first;
    unshift(@rest, $second) if defined $second;
  } elsif (ref $first eq 'ARRAY') {
    $tag = join ':', @$first, $tag;
    if (ref $second eq 'HASH') {
      $attr = $second;
    } else {
      unshift(@rest, $second) if defined $second;
    }
  } elsif (defined $first) {
    unshift(@rest, $second) if defined $second;
    unshift(@rest, $first);
  }
  $xml = "<$tag";
  if ($attr) {
    $xml .= ' ';
    $xml .= join ' ', map {qq|$_="$attr->{$_}"|} keys %$attr;
  }
  if (@rest) {
    $xml .= '>';
    $xml .= join $, || '',@rest;
    $xml .= "</$tag>";
  } else {
    $xml .= ' />';
  }
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

XML::Generator is an extremely simple module to help in the generation of
XML.  Basically, you create an XML::Generator object and then call a method
for each tag, supplying the contents of that tag as parameters.  You can use
a hash ref as the first parameter if the tag should include atributes.  If the
tag should be part of a namespace, supply an array ref as the first argument
with each level of the namespace an element in the array.  If you want to
specify a namespace as well as attributes, you can make the second argument a
hash ref.  If you do it the other way around, the array ref will simply get
stringified and included as part of the content of the tag. The XML is returned
as a string.  A valid XML document must consist of a single tag at the top
level, but this module does nothing to enforce that.

=head1 BUGS

There's no easy way to use namespaces on attributes.

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
