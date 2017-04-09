use strict;
use Test::More tests => 6;

use re::engine::PCRE2;
{
  use re::engine::PCRE2 ('matchlimit' => 2000);
  ok(exists $^H{regcomp}, '$^H{regcomp} exists');
  cmp_ok($^H{regcomp}, '!=', 0);
  my $qr = qr/./;
  is(re::engine::PCRE2::matchlimit(), 2000);
}

my $qr = qr/./;
is($qr->matchlimit(), 1000000);

{
  no re::engine::PCRE2;
  my $qr = qr/b/;
  isnt(ref $qr, "re::engine::PCRE2", 'not PCRE2, but');
  is(ref $qr, "Regexp", 'core re class');
}
