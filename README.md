# NAME 

re::engine::PCRE2 - PCRE2 regular expression engine

# SYNOPSIS

    use re::engine::PCRE2;

    if ("Hello, world" =~ /(?<=Hello|Hi), (world)/) {
        print "Greetings, $1!";
    }

# DESCRIPTION

Replaces perl's regex engine in a given lexical scope with PCRE2
regular expressions provided by libpcre.

This provides jit support and faster matching, but may fail in
cornercases. Note that most packaged libpcre2-8 libraries do not
enable the jit compiler. `cmake -DPCRE2_SUPPORT_JIT=ON`

# AUTHORS

Reini Urban <rurban@cpan.org>

# COPYRIGHT

Copyright 2007 Ævar Arnfjörð Bjarmason.
Copyright 2017 Reini Urban.

The original version was copyright 2006 Audrey Tang
<cpan@audreyt.org> and Yves Orton.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
