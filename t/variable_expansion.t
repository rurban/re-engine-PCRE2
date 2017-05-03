use strict;
use warnings;

use Test::More tests => 2;

use re::engine::PCRE2;

my $variable = 'll';
# These tests were fixed with 0.12, op_comp pat_count was ignored.

# This pattern matches erroneously, because anything after (and including) ${variable} is thrown out
ok("hello moon" !~ /^(he)${variable}o earth$/, "Variable expanded correctly, rest of the pattern not skipped!");

# This pattern won't compile, because the regex engine only sees /H\w(/:
# "Unmatched ( in regex; marked by <-- HERE in m/H\w( <-- HERE / at t/variable_expansion.t line 14."

ok(eval('"Hello" =~ /H\w($variable)o/'), "Variable expanded correctly, rest of the pattern not skipped!");

