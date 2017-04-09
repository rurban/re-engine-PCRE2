use strict;
use Test::More tests => 34;
use Config;
use re::engine::PCRE2;

my $qr = qr/(a(b?))/;
my $bit64 = $Config{ptrsize} == 8 ? 1 : 0;
my %m =
  (
   _alloptions => 64,
   _argoptions => 64,
   backrefmax => 0,
   bsr => 1,
   capturecount => 2,
   firstcodetype => 1,
   firstcodeunit => 97,
   hasbackslashc => 0,
   hascrorlf => 0,
   jchanged => 0,
   lastcodetype => 0,
   lastcodeunit => 0,
   matchempty => 0,
   matchlimit => 4294967295,
   maxlookbehind => 0,
   minlength => 1,
   namecount => 0,
   nameentrysize => 0,
   newline => 2,
  );
# default build-time configs
my %o =
  (
   BSR => 1,
   MATCHLIMIT => 10000000,
   NEWLINE => 2,
   PARENSLIMIT => 250,
   DEPTHLIMIT => $bit64 ? 10000000 : undef,
   RECURSIONLIMIT => 10000000,
   STACKRECURSE => $bit64 ? 1 : 0,
   UNICODE => 1,
  );

for (sort keys %m) {
  is($qr->$_, $m{$_}, "$_ $m{$_}");
}
ok($qr->size > 100, "size"); # 131 with 32bit, 155 with 64bit

my $s = re::engine::PCRE2::config('JITTARGET');
if (re::engine::PCRE2::JIT) {
  ok($qr->jitsize > 20, "jitsize");
  is(re::engine::PCRE2::config('JIT'), 1, "config JIT");
  ok($s, "config JITTARGET \"$s\"");
} else {
  is($qr->jitsize, 0, "no jitsize");
  is(re::engine::PCRE2::config('JIT'), 0, "config JIT");
  is($s, undef, "no config JITTARGET");
}

is(re::engine::PCRE2::config('invalid'), undef, "config invalid");
for (sort keys %o) {
  is(re::engine::PCRE2::config($_), $o{$_}, "config $_ $o{$_}");
}
$s = re::engine::PCRE2::config("UNICODE_VERSION");
like($s, qr/^\d/, "config UNICODE_VERSION \"$s\"");
$s = re::engine::PCRE2::config("VERSION");
like($s, qr/^10\.*/, "config VERSION \"$s\"");
