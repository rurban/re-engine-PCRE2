use Test::More tests => 2;
use re::engine::PCRE2;

my $re = qr/aoeu/;

isa_ok($re, "re::engine::PCRE2");
is("$re", "(?:aoeu)");
