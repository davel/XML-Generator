package XML::Generator;

use strict;
use vars qw/$VERSION $AUTOLOAD/;

$VERSION = 0.1;

sub new {bless {}, shift;}
sub DESTROY {}
sub AUTOLOAD {
  my($this, $first, @rest) = @_;
  my $tag = $AUTOLOAD;
  $tag =~ s/.*:://;
  my $xml = "<$tag";
  if (ref $first eq 'HASH') {
    $xml .= ' ';
    $xml .= join ' ', map {qq|$_="$first->{$_}"|} keys %$first;
  } elsif ($first) {
    unshift(@rest, $first);
  }
  if (@rest) {
    $xml .= '>';
    $xml .= join $,,@rest;
    $xml .= "</$tag>";
  } else {
    $xml .= '/>';
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
		$x->bar("Hey there,\n", "world"));
  __END__
  # The above would yield:
  <foo><bar baz="3"><bam/></bar><bar>Hey there,
world</bar></foo>


=head1 DESCRIPTION

XML::Generator is an extremely simple module to help in the generation of
XML.  It has no support for entities currently.  Basically, you create an
XML::Generator object and then call a method for each tag, supplying the
contents of that tag as parameters.  You can use a hash ref as the first
parameter if the tag should include atributes.  The XML is returned as a
string.  A valid XML document must consist of a single tag at the top level,
but this module does nothing to enforce that.

=head1 AUTHOR

Benjamin Holzman, bholzman@bender.com

=head1 SEE ALSO

Perl-XML FAQ

http://www.pobox.com/~eisen/xml/perl-xml-faq.html

=cut
