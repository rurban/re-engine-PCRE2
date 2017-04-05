package re::engine::PCRE2;
our ($VERSION, $XS_VERSION);
BEGIN {
  $VERSION = '0.02';
  $XS_VERSION = $VERSION;
  $VERSION = eval $VERSION;
}
use 5.010;
use XSLoader ();

# All engines should subclass the core Regexp package
our @ISA = 'Regexp';

BEGIN {
  XSLoader::load;
}

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
cornercases.

Note that some packaged libpcre2-8 libraries do not enable the jit
compiler. C<cmake -DPCRE2_SUPPORT_JIT=ON>
PCRE2 then silently falls back to the normal PCRE2 compiler and matcher.

Check with:

  perl -Mre::engine::PCRE2 -e'print re::engine::PCRE2::JIT'
  perl -Mre::engine::PCRE2 -e'print re::engine::PCRE2::JITTARGET'

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
