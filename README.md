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

- match\_limit (RX, \[INT\])

    NYI

- offset\_limit (RX, \[INT\])

    NYI

- recursion\_limit (RX, \[INT\])

    NYI

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
