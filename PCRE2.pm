package re::engine::PCRE2;
our ($VERSION, $XS_VERSION);
BEGIN {
  $VERSION = '0.02';
  $XS_VERSION = $VERSION;
  $VERSION = eval $VERSION;
}
use 5.010;
use strict;
use XSLoader ();

# All engines should subclass the core Regexp package
our @ISA = 'Regexp';

BEGIN {
  XSLoader::load;
}

# TODO: set context options, and save prev. ones for unimport.
# compile-ctx and match-ctx
sub import {
  $^H{regcomp} = ENGINE;
}

sub unimport {
  delete $^H{regcomp} if $^H{regcomp} == ENGINE;
}

1;

__END__

=head1 NAME 

re::engine::PCRE2 - PCRE2 regular expression engine with jit

=head1 SYNOPSIS

    use re::engine::PCRE2;

    if ("Hello, world" =~ /(?<=Hello|Hi), (world)/) {
        print "Greetings, $1!";
    }

=head1 DESCRIPTION

Replaces perl's regex engine in a given lexical scope with PCRE2
regular expressions provided by libpcre2-8.

This provides jit support and faster matching, but may fail in
corner cases. See L<pcre2compat|http://www.pcre.org/current/doc/html/pcre2compat.html>.
It is typically 10% faster then the core regex engine.

Note that some packaged libpcre2-8 libraries do not enable the jit
compiler. C<cmake -DPCRE2_SUPPORT_JIT=ON>
PCRE2 then silently falls back to the normal PCRE2 compiler and matcher.

Check with:

  perl -Mre::engine::PCRE2 -e'print re::engine::PCRE2::JIT'
  perl -Mre::engine::PCRE2 -e'print re::engine::PCRE2::JITTARGET'

=head1 METHODS

Since re::engine::PCRE2 derives from the C<Regexp> package, you can call
compiled C<qr//> objects with these methods.
See L<PCRE2 NATIVE API MATCH CONTEXT FUNCTIONS|http://www.pcre.org/current/doc/html/pcre2api.html#SEC5>

=over

=item match_limit (RX, [INT])

NYI

=item offset_limit (RX, [INT])

NYI

=item recursion_limit (RX, [INT])

NYI

=back

=head1 FUNCTIONS

=over

=item import

import lexically sets the PCRE2 engine to be active.

import will later accept compile context options.
See L<PCRE2 NATIVE API COMPILE CONTEXT FUNCTIONS|http://www.pcre.org/current/doc/html/pcre2api.html#SEC4>.

  bsr => int
  max_pattern_length => int
  newline => int
  parens_nest_limit => int

=item unimport

unimport sets the regex engine to the previous one.
If PCRE2 with the previous context options.

=item ENGINE

Returns a pointer to the internal PCRE2 engine, suitable for the
XS API C<<< (regexp*)re->engine >>> field.

=item JIT

Returns 1 or 0, if the JIT engine is available or not.

=item JITTARGET

Returns a string describing the JIT target description or nothing.
On Intel this is typically "x86 64bit (little endian + unaligned)".

=item config (OPTION)

Returns build-time information about libpcre2.
Note that some of these options may later be set'able at run-time.

OPTIONS can be one of the following strings:

    JITTARGET
    UNICODE_VERSION
    VERSION

    BSR
    JIT
    LINKSIZE
    MATCHLIMIT
    NEWLINE
    PARENSLIMIT
    DEPTHLIMIT
    RECURSIONLIMIT
    STACKRECURSE
    UNICODE

The first three options return a string, the rest an integer.
See L<http://www.pcre.org/current/doc/html/pcre2api.html#SEC17>.

NEWLINE returns an integer, representing:

   PCRE2_NEWLINE_CR          1
   PCRE2_NEWLINE_LF          2
   PCRE2_NEWLINE_CRLF        3
   PCRE2_NEWLINE_ANY         4  Any Unicode line ending
   PCRE2_NEWLINE_ANYCRLF     5  Any of CR, LF, or CRLF

The default is OS specific.

BSR returns an integer, representing:

   PCRE2_BSR_UNICODE         1
   PCRE2_BSR_ANYCRLF         2

A value of PCRE2_BSR_UNICODE means that C<\R> matches any Unicode line
ending sequence; a value of PCRE2_BSR_ANYCRLF means that C<\R> matches
only CR, LF, or CRLF.

The default is 1 for UNICODE, as all libpcre2 libraries are now compiled
with unicode support builtin. (C<--enable-unicode>).

=back


=head1 AUTHORS

Reini Urban <rurban@cpan.org>

=head1 COPYRIGHT

Copyright 2007 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.
Copyright 2017 Reini Urban.

The original version was copyright 2006 Audrey Tang
E<lt>cpan@audreyt.orgE<gt> and Yves Orton.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
