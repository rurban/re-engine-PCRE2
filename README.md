# NAME 

re::engine::PCRE2 - PCRE2 regular expression engine with jit

# SYNOPSIS

    use re::engine::PCRE2;

    if ("Hello, world" =~ /(?<=Hello|Hi), (world)/) {
        print "Greetings, $1!";
    }

# DESCRIPTION

Replaces perl's regex engine in a given lexical scope with PCRE2
regular expressions provided by libpcre2-8.

This provides jit support and faster matching, but may fail in
corner cases. See [pcre2compat](http://www.pcre.org/current/doc/html/pcre2compat.html).
It is typically 10% faster then the core regex engine.

Note that some packaged libpcre2-8 libraries do not enable the jit
compiler. `cmake -DPCRE2_SUPPORT_JIT=ON`
PCRE2 then silently falls back to the normal PCRE2 compiler and matcher.

Check with:

    perl -Mre::engine::PCRE2 -e'print re::engine::PCRE2::JIT'
    perl -Mre::engine::PCRE2 -e'print re::engine::PCRE2::JITTARGET'

# METHODS

Since re::engine::PCRE2 derives from the `Regexp` package, you can call
compiled `qr//` objects with these methods.
See [PCRE2 NATIVE API MATCH CONTEXT FUNCTIONS](http://www.pcre.org/current/doc/html/pcre2api.html#SEC5)
and [INFORMATION ABOUT A COMPILED PATTERN](http://www.pcre.org/current/doc/html/pcre2api.html#SEC22)

- match\_limit (RX, \[INT\])

    NYI

- offset\_limit (RX, \[INT\])

    NYI

- recursion\_limit (RX, \[INT\])

    NYI

- \_alloptions (RX)

    The result of pcre2\_pattern\_info(PCRE2\_INFO\_ALLOPTIONS) as unsigned integer.

- \_argoptions (RX)

    The result of pcre2\_pattern\_info(PCRE2\_INFO\_ARGOPTIONS) as unsigned integer.

- backrefmax (RX)

    Return the number of the highest back reference in the pattern.

- bsr (RX)

    What character sequences the `\R` escape sequence matches.
    1 means that `\R` matches any Unicode line ending sequence;
    2 means that `\R` matches only CR, LF, or CRLF.

- capturecount (RX)

    Return the highest capturing subpattern number in the pattern. In
    patterns where `(?|` is not used, this is also the total number of
    capturing subpatterns.

- firstbitmap (RX)

    In the absence of a single first code unit for a non-anchored pattern,
    `pcre2_compile()` may construct a 256-bit table that defines a fixed set
    of values for the first code unit in any match. For example, a pattern
    that starts with `[abc]` results in a table with three bits set. When
    code unit values greater than 255 are supported, the flag bit for 255
    means "any code unit of value 255 or above". If such a table was
    constructed, it is returned as string.

- firstcodetype (RX)

    Return information about the first code unit of any matched string,
    for a non-anchored pattern. If there is a fixed first value, for
    example, the letter "c" from a pattern such as `(cat|cow|coyote)`, 1
    is returned, and the character value can be retrieved using
    ["firstcodeunit"](#firstcodeunit). If there is no fixed first value, but it is known
    that a match can occur only at the start of the subject or following a
    newline in the subject, 2 is returned. Otherwise, and for anchored
    patterns, 0 is returned.

- firstcodeunit (RX)

    Return the value of the first code unit of any matched string in the
    situation where ["firstcodetype (RX)"](#firstcodetype-rx) returns 1; otherwise return
    0\. In the 8-bit library, the value is always less than 256. In the
    16-bit library the value can be up to 0xffff. In the 32-bit library in
    UTF-32 mode the value can be up to 0x10ffff, and up to 0xffffffff when
    not using UTF-32 mode.

- hasbackslashc (RX)

    Return 1 if the pattern contains any instances of \\C, otherwise 0.

- hascrorlf (RX)

    Return 1 if the pattern contains any explicit matches for CR or LF
    characters, otherwise 0. An explicit match is either a literal CR or LF
    character, or \\r or \\n.

- jchanged (RX)

    Return 1 if the (?J) or (?-J) option setting is used in the pattern,
    otherwise 0. (?J) and (?-J) set and unset the local PCRE2\_DUPNAMES
    option, respectively.

- jitsize (RX)

    If the compiled pattern was successfully processed by
    pcre2\_jit\_compile(), return the size of the JIT compiled code,
    otherwise return zero.

- lastcodetype (RX)

    Returns 1 if there is a rightmost literal code unit that must exist in
    any matched string, other than at its start. If there is no such value, 0 is
    returned. When 1 is returned, the code unit value itself can be
    retrieved using ["lastcodeunit (RX)"](#lastcodeunit-rx). For anchored patterns, a last
    literal value is recorded only if it follows something of variable
    length. For example, for the pattern `/^a\d+z\d+/` the returned value is
    1 (with "z" returned from lastcodeunit), but for `/^a\dz\d/`
    the returned value is 0.

- lastcodeunit

    Return the value of the rightmost literal data unit that must exist in
    any matched string, other than at its start, if such a value has been
    recorded. The third argument should point to an uint32\_t variable. If
    there is no such value, 0 is returned.

- matchempty

    Return 1 if the pattern might match an empty string, otherwise 0. The
    third argument should point to an uint32\_t variable. When a pattern
    contains recursive subroutine calls it is not always possible to
    determine whether or not it can match an empty string. PCRE2 takes a
    cautious approach and returns 1 in such cases.

- matchlimit

    If the pattern set a match limit by including an item of the form
    (\*LIMIT\_MATCH=nnnn) at the start, the value is returned.

- maxlookbehind

    Return the number of characters (not code units) in the longest
    lookbehind assertion in the pattern. The third argument should point
    to an unsigned 32-bit integer. This information is useful when doing
    multi-segment matching using the partial matching facilities. Note
    that the simple assertions \\b and \\B require a one-character
    lookbehind. \\A also registers a one-character lookbehind, though it
    does not actually inspect the previous character. This is to ensure
    that at least one character from the old segment is retained when a
    new segment is processed. Otherwise, if there are no lookbehinds in
    the pattern, \\A might match incorrectly at the start of a new segment.

- minlength

    If a minimum length for matching subject strings was computed, its
    value is returned. Otherwise the returned value is 0. The value is a
    number of characters, which in UTF mode may be different from the
    number of code units. The third argument should point to an uint32\_t
    variable. The value is a lower bound to the length of any matching
    string. There may not be any strings of that length that do actually
    match, but every string that does match is at least that long.

- namecount (RX)
- nameentrysize (RX)

    PCRE2 supports the use of named as well as numbered capturing
    parentheses. The names are just an additional way of identifying the
    parentheses, which still acquire numbers. Several convenience
    functions such as pcre2\_substring\_get\_byname() are provided for
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

- newline (RX)

    Returns the newline regime, see below at ["config (OPTION)"](#config-option).

- recursionlimit (RX)

    If the pattern set a recursion limit by including an item of the form
    (\*LIMIT\_RECURSION=nnnn) at the start, the value is returned.

- size (RX)

    Return the size of the compiled pattern in bytes (for all three
    libraries). The third argument should point to a size\_t variable. This
    value includes the size of the general data block that precedes the
    code units of the compiled pattern itself. The value that is used when
    `pcre2_compile()` is getting memory in which to place the compiled
    pattern may be slightly larger than the value returned by this option,
    because there are cases where the code that calculates the size has to
    over-estimate. Processing a pattern with the JIT compiler does not
    alter the value returned by this option.

# FUNCTIONS

- import

    import lexically sets the PCRE2 engine to be active.

    import will later accept compile context options.
    See [PCRE2 NATIVE API COMPILE CONTEXT FUNCTIONS](http://www.pcre.org/current/doc/html/pcre2api.html#SEC4).

        bsr => int
        max_pattern_length => int
        newline => int
        parens_nest_limit => int

- unimport

    unimport sets the regex engine to the previous one.
    If PCRE2 with the previous context options.

- ENGINE

    Returns a pointer to the internal PCRE2 engine, suitable for the
    XS API `(regexp*)re->engine` field.

- JIT

    Returns 1 or 0, if the JIT engine is available or not.

- JITTARGET

    Returns a string describing the JIT target description or nothing.
    On Intel this is typically "x86 64bit (little endian + unaligned)".

- config (OPTION)

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
    See [http://www.pcre.org/current/doc/html/pcre2api.html#SEC17](http://www.pcre.org/current/doc/html/pcre2api.html#SEC17).

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

    A value of PCRE2\_BSR\_UNICODE means that `\R` matches any Unicode line
    ending sequence; a value of PCRE2\_BSR\_ANYCRLF means that `\R` matches
    only CR, LF, or CRLF.

    The default is 1 for UNICODE, as all libpcre2 libraries are now compiled
    with unicode support builtin. (`--enable-unicode`).

# AUTHORS

Reini Urban <rurban@cpan.org>

# COPYRIGHT

Copyright 2007 Ævar Arnfjörð Bjarmason.
Copyright 2017 Reini Urban.

The original version was copyright 2006 Audrey Tang
<cpan@audreyt.org> and Yves Orton.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
