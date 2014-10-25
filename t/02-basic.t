#!perl -w
#
# $Id: 02-basic.t,v 0.1 2007/04/27 17:17:46 dankogai Exp $
#
# Original as URI-1.35/t/escape.t
#

use URI::Escape::XS;
use Test::More tests => 512;

# basic round-trip test
for my $ord (  0 .. 255 ) {
    use bytes;
    my $chr = chr $ord;
    my $esc = $chr =~ /[A-Za-z0-9\-_.!~*'()]/ ? $chr : sprintf "%%%02X", $ord;
    is encodeURIComponent($chr) => $esc, "encodeURIComponent(ord $ord)";
    is decodeURIComponent($esc) => $chr, "decodeURIComponent($esc)";
}
