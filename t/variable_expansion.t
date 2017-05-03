use strict;
use warnings;

use Test::More tests => 2;

use re::engine::PCRE2;

my $variable = 'll';

TODO: {
    local $TODO = "Broken due to op_comp implementation - fix is work in progress";
    # The following tests fail with newer-ish perls - anything that uses the op_comp implementation.

    # This pattern matches erroneously, because anything after (and including) ${variable} is thrown out
    ok("hello moon" !~ /^(he)${variable}o earth$/, "Variable expanded correctly, rest of the pattern not skipped!");

    # This pattern won't compile, because the regex engine only sees /H\w(/:
    # "Unmatched ( in regex; marked by <-- HERE in m/H\w( <-- HERE / at t/variable_expansion.t line 14."

    ok(eval('"Hello" =~ /H\w($variable)o/'), "Variable expanded correctly, rest of the pattern not skipped!");
};
