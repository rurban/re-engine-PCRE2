package re::engine::PCRE2;
our ($VERSION, $XS_VERSION);
BEGIN {
  $VERSION = '0.04';
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

# set'able via import
our @CONTEXT_OPTIONS = qw(
  bsr max_pattern_length newline parens_nest_limit
  match_limit offset_limit recursion_limit
);

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
=encoding UTF-8

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

This provides jit support and faster matching, but may fail in corner
cases. See
L<pcre2compat|http://www.pcre.org/current/doc/html/pcre2compat.html>.
It is typically 10% faster than the core regex engine. I<(realistic
benchmarks outstanding)>.

The goal is to pass the full core re testsuite, identify all
problematic patterns and fall-back to the core re engine.  From the
1330 core tests, 46 currently fail. 90% of the most popular cpan
modules do work fine already.  See L</FAILING TESTS>.

Note that some packaged libpcre2-8 libraries do not enable the jit
compiler. C<CFLAGS=-fPIC cmake -DPCRE2_SUPPORT_JIT=ON; make>
PCRE2 then silently falls back to the normal PCRE2 compiler and matcher.

Check with:

  perl -Mre::engine::PCRE2 -e'print re::engine::PCRE2::JIT'

=head1 METHODS

Since re::engine::PCRE2 derives from the C<Regexp> package, you can call
compiled C<qr//> objects with these methods.
See L<PCRE2 NATIVE API MATCH CONTEXT FUNCTIONS|http://www.pcre.org/current/doc/html/pcre2api.html#SEC5>
and L<INFORMATION ABOUT A COMPILED PATTERN|http://www.pcre.org/current/doc/html/pcre2api.html#SEC22>

=over

=item match_limit (RX, [INT])

Get or set the match_limit match context. NYI

=item offset_limit (RX, [INT])

NYI

=item recursion_limit (RX, [INT])

NYI

=item _alloptions (RX)

The result of pcre2_pattern_info(PCRE2_INFO_ALLOPTIONS) as unsigned integer.

   my $q=qr/(a)/; print $q->_alloptions
   => 64

64 stands for PCRE2_DUPNAMES which is always set. See F<pcre2.h>

=item _argoptions (RX)

The result of pcre2_pattern_info(PCRE2_INFO_ARGOPTIONS) as unsigned integer.

   my $q=qr/(a)/i; print $q->_argoptions
   => 72

72 = 64+8
64 stands for PCRE2_DUPNAMES which is always set.
8 for PCRE2_CASELESS.
See F<pcre2.h>

=item backrefmax (RX)

Return the number of the highest back reference in the pattern.

  my $q=qr/(a)\1/; print $q->backrefmax
  => 1
  my $q=qr/(a)(?(1)a|b)/; print $q->backrefmax
  => 1

=item bsr (RX)

What character sequences the C<\R> escape sequence matches.
1 means that C<\R> matches any Unicode line ending sequence;
2 means that C<\R> matches only CR, LF, or CRLF.

=item capturecount (RX)

Return the highest capturing subpattern number in the pattern. In
patterns where C<(?|> is not used, this is also the total number of
capturing subpatterns.

  my $q=qr/(a(b))/; print $q->capturecount
  => 2

=item firstbitmap (RX)

In the absence of a single first code unit for a non-anchored pattern,
C<pcre2_compile()> may construct a 256-bit table that defines a fixed set
of values for the first code unit in any match. For example, a pattern
that starts with C<[abc]> results in a table with three bits set. When
code unit values greater than 255 are supported, the flag bit for 255
means "any code unit of value 255 or above". If such a table was
constructed, it is returned as string.

=item firstcodetype (RX)

Return information about the first code unit of any matched string,
for a non-anchored pattern. If there is a fixed first value, for
example, the letter "c" from a pattern such as C<(cat|cow|coyote)>, 1
is returned, and the character value can be retrieved using
L</firstcodeunit>. If there is no fixed first value, but it is known
that a match can occur only at the start of the subject or following a
newline in the subject, 2 is returned. Otherwise, and for anchored
patterns, 0 is returned.

=item firstcodeunit (RX)

Return the value of the first code unit of any matched string in the
situation where L</firstcodetype (RX)> returns 1; otherwise return
0. The value is always less than 256.

  my $q=qr/(cat|cow|coyote)/; print $q->firstcodetype, $q->firstcodeunit
  => 1 99

=item hasbackslashc (RX)

Return 1 if the pattern contains any instances of \C, otherwise 0.
Note that \C is forbidden since perl 5.26 (?).

=item hascrorlf (RX)

Return 1 if the pattern contains any explicit matches for CR or LF
characters, otherwise 0. An explicit match is either a literal CR or LF
character, or \r or \n.

=item jchanged (RX)

Return 1 if the (?J) or (?-J) option setting is used in the pattern,
otherwise 0. (?J) and (?-J) set and unset the local PCRE2_DUPNAMES
option, respectively.

=item jitsize (RX)

If the compiled pattern was successfully processed by
pcre2_jit_compile(), return the size of the JIT compiled code,
otherwise return zero.

=item lastcodetype (RX)

Returns 1 if there is a rightmost literal code unit that must exist in
any matched string, other than at its start. If there is no such value, 0 is
returned. When 1 is returned, the code unit value itself can be
retrieved using L</lastcodeunit (RX)>. For anchored patterns, a last
literal value is recorded only if it follows something of variable
length. For example, for the pattern C</^a\d+z\d+/> the returned value is
1 (with "z" returned from lastcodeunit), but for C</^a\dz\d/>
the returned value is 0.

=item lastcodeunit (RX)

Return the value of the rightmost literal data unit that must exist in
any matched string, other than at its start, if such a value has been
recorded. If there is no such value, 0 is returned.

=item matchempty (RX)

Return 1 if the pattern might match an empty string, otherwise 0. When
a pattern contains recursive subroutine calls it is not always
possible to determine whether or not it can match an empty
string. PCRE2 takes a cautious approach and returns 1 in such cases.

=item matchlimit (RX)

If the pattern set a match limit by including an item of the form
(*LIMIT_MATCH=nnnn) at the start, the value is returned.

=item maxlookbehind (RX)

Return the number of characters (not code units) in the longest
lookbehind assertion in the pattern. This information is useful when
doing multi-segment matching using the partial matching
facilities. Note that the simple assertions \b and \B require a
one-character lookbehind. \A also registers a one-character
lookbehind, though it does not actually inspect the previous
character. This is to ensure that at least one character from the old
segment is retained when a new segment is processed. Otherwise, if
there are no lookbehinds in the pattern, \A might match incorrectly at
the start of a new segment.

=item minlength (RX)

If a minimum length for matching subject strings was computed, its
value is returned. Otherwise the returned value is 0. The value is a
number of characters, which in UTF mode may be different from the
number of code units. The value is a lower bound to the length of any
matching string. There may not be any strings of that length that do
actually match, but every string that does match is at least that
long.

=item namecount (RX)

=item nameentrysize (RX)

PCRE2 supports the use of named as well as numbered capturing
parentheses. The names are just an additional way of identifying the
parentheses, which still acquire numbers. Several convenience
functions such as pcre2_substring_get_byname() are provided for
extracting captured substrings by name. It is also possible to extract
the data directly, by first converting the name to a number in order
to access the correct pointers in the output vector. To do the
conversion, you need to use the name-to-number map, which is described
by these three values.

The map consists of a number of fixed-size
entries. namecount gives the number of entries, and
nameentrysize gives the size of each entry in code units;
The entry size depends on the length of the longest name.

The nametable itself is not yet returned.

=item newline (RX)

Returns the newline regime, see below at L</config (OPTION)>.

=item recursionlimit (RX)

If the pattern set a recursion limit by including an item of the form
(*LIMIT_RECURSION=nnnn) at the start, the value is returned.

=item size (RX)

Return the size of the compiled pattern in bytes.  This value includes
the size of the general data block that precedes the code units of the
compiled pattern itself. The value that is used when
C<pcre2_compile()> is getting memory in which to place the compiled
pattern may be slightly larger than the value returned by this option,
because there are cases where the code that calculates the size has to
over-estimate. Processing a pattern with the JIT compiler does not
alter the value returned by this option.

=back

=head1 FUNCTIONS

=over

=item import

import lexically sets the PCRE2 engine to be active.

import will later accept compile context options.
See L<PCRE2 NATIVE API COMPILE CONTEXT FUNCTIONS|http://www.pcre.org/current/doc/html/pcre2api.html#SEC4>.

  bsr => INT
  max_pattern_length => INT
  newline => INT
  parens_nest_limit => INT

  match_limit => INT
  offset_limit => INT
  recursion_limit => INT

=item unimport

unimport sets the regex engine to the previous one.
If PCRE2 with the previous context options.

=item ENGINE

Returns a pointer to the internal PCRE2 engine, suitable for the
XS API C<<< (regexp*)re->engine >>> field.

=item JIT

Returns 1 or 0, if the JIT engine is available or not.

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

=head1 FAILING TESTS

About 90% of all core tests and cpan modules do work with re::engine::PCRE2
already, but there are still some unresolved problems.
Try the new faster matcher with C<export PERL5OPT=-Mre::engine::PCRE2>.

Known problematic popular modules are: Test-Harness-3.38,
Params-Util-1.07 I<t/12_main.t 552-553, 567-568>, HTML-Parser-3.72
I<(unicode)>, DBI-1.636 I<(EUMM problem)>, DBD-SQLite-1.54
I<(xsubpp)>, Sub-Name-0.21 I<t/exotic_names.t:105>, XML-LibXML-2.0129
I<(local charset)>, Module-Install-1.18 I<unrecognized character after
(?  or (?->, Text-CSV_XS-1.28 I<(unicode)>, YAML-Syck-1.29, MD5-2.03,
XML-Parser-2.44, Module-Build-0.4222, libwww-perl-6.25.

As of 0.04 the following core regression tests still fail:

    perl -C -Mblib t/perl/regexp.t | grep -a TODO

    301: '^'i:ABC:y:$&: => `'', match=
    353: '(a+|b){0,1}?'i:AB:y:$&-$1:- => `A-A', match=1
    357: 'a*'i::y:$&: => `'', match=
    497: a(?{"{"})b:-:c:-:Sequence (?{...}) not terminated or not {}-balanced => `-', match=
    589:(utf8::upgrade($subject)) ([[:^alnum:]]+):ABcd01Xy__--  ${nulnul}${ffff}:y:$1:__--  ${nulnul}${ffff} => `__--  \0\0Ã¿Ã¿', match=1
    590:(utf8::upgrade($subject)) ([[:^ascii:]]+):ABcd01Xy__--  ${nulnul}${ffff}:y:$1:${ffff} => `Ã¿Ã¿', match=1
    594:(utf8::upgrade($subject)) ([[:^print:]]+):ABcd01Xy__--  ${nulnul}${ffff}:y:$1:${nulnul}${ffff} => `\0\0Ã¿Ã¿', match=1
    597:(utf8::upgrade($subject)) ([[:^word:]]+):ABcd01Xy__--  ${nulnul}${ffff}:y:$1:--  ${nulnul}${ffff} => `--  \0\0Ã¿Ã¿', match=1
    599:(utf8::upgrade($subject)) ([[:^xdigit:]]+):ABcd01Xy__--  ${nulnul}${ffff}:y:$1:Xy__--  ${nulnul}${ffff} => `Xy__--  \0\0Ã¿Ã¿', match=1
    606: a{37,17}:-:c:-:Can't do {n,m} with n > m => `-', match=
    813:.X(.+)+X:bbbbXcXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    814:.X(.+)+XX:bbbbXcXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    815:.XX(.+)+X:bbbbXXcXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    816:.X(.+)+X:bbbbXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    817:.X(.+)+XX:bbbbXXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    818:.XX(.+)+X:bbbbXXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    819:.X(.+)+[X]:bbbbXcXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    820:.X(.+)+[X][X]:bbbbXcXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    821:.XX(.+)+[X]:bbbbXXcXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    822:.X(.+)+[X]:bbbbXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    823:.X(.+)+[X][X]:bbbbXXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    824:.XX(.+)+[X]:bbbbXXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    825:.[X](.+)+[X]:bbbbXcXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    826:.[X](.+)+[X][X]:bbbbXcXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    827:.[X][X](.+)+[X]:bbbbXXcXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:y:-:- => error `PCRE2 error -47'
    828:.[X](.+)+[X]:bbbbXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    829:.[X](.+)+[X][X]:bbbbXXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    830:.[X][X](.+)+[X]:bbbbXXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:n:-:- => error `PCRE2 error -47'
    867: ^(a(b)?)+$:aba:y:-$1-$2-:-a-- => `-a-b-', match=1
    868: ^(aa(bb)?)+$:aabbaa:y:-$1-$2-:-aa-- => `-aa-bb-', match=1
    873: ^(a\1?){4}$:aaaaaa:y:$1:aa => `', match=
    931:(??{}):x:y:-:- => error `Eval-group not allowed at runtime, use re 'eval' in regex m/(??{})/ at (eval 5345) line 2.'
    1021: ^(<(?:[^<>]+|(?3)|(?1))*>)()(!>!>!>)$:<<!>!>!>><>>!>!>!>:y:$1:<<!>!>!>><>> => `', match=
    1051: /^(?'main'<(?:[^<>]+|(?&crap)|(?&main))*>)(?'empty')(?'crap'!>!>!>)$/:<<!>!>!>><>>!>!>!>:y:$+{main}:<<!>!>!>><>> => `', match=
    1291:(utf8::upgrade($subject)) foo(\R+)bar:foo\r
    1293:(utf8::upgrade($subject)) (\R+)(\V):foo\r
    1294:(utf8::upgrade($subject)) foo(\R)bar:foo\x{85}bar:y:$1:\x{85} => `', match=
    1295:(utf8::upgrade($subject)) (\V)(\R):foo\x{85}bar:y:$1-$2:o-\x{85} => `Â-', match=1
    1307:(utf8::upgrade($subject)) foo(\v+)bar:foo\r
    1309:(utf8::upgrade($subject)) (\v+)(\V):foo\r
    1310:(utf8::upgrade($subject)) foo(\v)bar:foo\x{85}bar:y:$1:\x{85} => `', match=
    1311:(utf8::upgrade($subject)) (\V)(\v):foo\x{85}bar:y:$1-$2:o-\x{85} => `Â-', match=1
    1318:(utf8::upgrade($subject)) foo(\h+)bar:foo\t\x{A0}bar:y:$1:\t\x{A0} => `', match=
    1320:(utf8::upgrade($subject)) (\h+)(\H):foo\t\x{A0}bar:y:$1-$2:\t\x{A0}-b => `	-Â', match=1
    1321:(utf8::upgrade($subject)) foo(\h)bar:foo\x{A0}bar:y:$1:\x{A0} => `', match=
    1322:(utf8::upgrade($subject)) (\H)(\h):foo\x{A0}bar:y:$1-$2:o-\x{A0} => `Â- ', match=1

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
