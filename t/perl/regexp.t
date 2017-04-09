#!./perl

use Test::More;

# The tests are in a separate file 't/perl/re_tests'.
# Each line in that file is a separate test.
# There are five columns, separated by tabs.
#
# Column 1 contains the pattern, optionally enclosed in C<''> C<::> or
# C<//>.  Modifiers can be put after the closing delimiter.  C<''> will
# automatically be added to any other patterns.
#
# Column 2 contains the string to be matched.
#
# Column 3 contains the expected result:
# 	y	expect a match
# 	n	expect no match
# 	c	expect an error
#	B	test exposes a known bug in Perl, should be skipped
#	b	test exposes a known bug in Perl, should be skipped if noamp
#	T	the test is a TODO (can be combined with y/n/c/p)
#	M	skip test on miniperl (combine with y/n/c/T)
#	t	test exposes a bug with threading, TODO if qr_embed_thr
#       s       test should only be run for regex_sets_compat.t
#       S       test should not be run for regex_sets_compat.t
#       a       test should only be run on ASCII platforms
#       e       test should only be run on EBCDIC platforms
#       p       exposes a PCRE bug/limitation. TODO
#
# Columns 4 and 5 are used only if column 3 contains C<y> or C<c>.
#
# Column 4 contains a string, usually C<$&>.
#
# Column 5 contains the expected result of double-quote
# interpolating that string after the match, or start of error message.
#
# Column 6, if present, contains a reason why the test is skipped.
# This is printed with "skipped", for harness to pick up.
#
# Column 7 can be used for comments
#
# \n in the tests are interpolated, as are variables of the form ${\w+}.
#
# Blanks lines are treated as PASSING tests to keep the line numbers
# linked to the test number.
#
# If you want to add a regular expression test that can't be expressed
# in this format, don't add it here: put it in op/pat.t instead.
#
# Note that columns 2,3 and 5 are all enclosed in double quotes and then
# evalled; so something like a\"\x{100}$1 has length 3+length($1).
#
# \x... and \o{...} constants are automatically converted to the native
# character set if necessary.  \[0-7] constants aren't

my $file;
BEGIN {
    $iters = shift || 1;	# Poor man performance suite, 10000 is OK.

    # Do this open before any chdir
    $file = shift;
    if (defined $file) {
	open TESTS, $file or die "Can't open $file";
    }
}

sub _comment {
    return map { /^#/ ? "$_\n" : "# $_\n" }
           map { split /\n/ } @_;
}

sub convert_from_ascii {
    my $string = shift;

    #my $save = $string;
    # Convert \x{...}, \o{...}
    $string =~ s/ (?<! \\ ) \\x\{ ( .*? ) } / "\\x{" . sprintf("%X", utf8::unicode_to_native(hex $1)) .  "}" /gex;
    $string =~ s/ (?<! \\ ) \\o\{ ( .*? ) } / "\\o{" . sprintf("%o", utf8::unicode_to_native(oct $1)) .  "}" /gex;

    # Convert \xAB
    $string =~ s/ (?<! \\ ) \\x ( [A-Fa-f0-9]{2} ) / "\\x" . sprintf("%02X", utf8::unicode_to_native(hex $1)) /gex;

    # Convert \xA
    $string =~ s/ (?<! \\ ) \\x ( [A-Fa-f0-9] ) (?! [A-Fa-f0-9] ) / "\\x" . sprintf("%X", utf8::unicode_to_native(hex $1)) /gex;

    #print STDERR __LINE__, ": $save\n$string\n" if $save ne $string;
    return $string;
}

use strict;
use warnings FATAL=>"all";
use vars qw($iters $numtests $bang $ffff $nulnul $OP);
use vars qw($skip_amp $qr $qr_embed); # set by our callers
use re::engine::PCRE2 ();
use re 'eval';
use Data::Dumper;

if (!defined $file) {
    open(TESTS,'t/perl/re_tests') || open(TESTS,'re_tests') || open(TESTS,'t/re_tests')
      || die "Can't open t/perl/re_tests: $!";
}

my @tests = <TESTS>;

close TESTS;

$bang = sprintf "\\%03o", ord "!"; # \41 would not be portable.
$ffff  = chr(0xff) x 2;
$nulnul = "\0" x 2;
my $OP = $qr ? 'qr' : 'm';

$| = 1;
printf "1..%d\n# $iters iterations\n", scalar @tests;
my $test;
my $skip_rest;


# Tests known to fail under PCRE2
my (@pcre_fail, %pcre_fail, @pcre_skip, %pcre_skip);
# see p in re_tests instead
my @pcre_fail_ignored = (

    # new patterns and pcre2 fails: need to fallback
    135..138, # \B{gcb} \B{lb} \B{sb} \B{wb}
    344,      # '^'i:ABC:y:$&:
    397,      # '(a+|b){0,1}?'i
    401,      # 'a*'i $&
    570,      # '(b.)c(?!\N)'s:a
    646,647,656, # unicode
    659,      # '[[:^cntrl:]]+'u:a\x80:y:$&:a

    # old PCRE fails:
    # Pathological patterns that run into run-time PCRE_ERROR_MATCHLIMIT,
    # even with huge set_match_limit 512mill
    872 .. 889, # .X(.+)+[X][X]:bbbbXXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

    # err: [a-[:digit:]] => range out of order in character class
    # 892,894,896,898,900,902, # was different False range error msg

    # offset: +59
    # aba =~ ^(a(b)?)+$ and aabbaa =~ ^(aa(bb)?)+$
    #867 .. 868,
    # err: (?!)+ => nothing to repeat
    #970,
    # XXX: <<<>>> pattern
    #1021,
    # XXX: Some named capture error
    #1050 .. 1051,
    # (*F) / (*FAIL)
    #1191, 1192,
    # (*A) / (*ACCEPT)
    #1194 .. 1195,
    # (?'${number}$optional_stuff' key names)
    #1217 .. 1223,
    # XXX: Some named capture error
    #1253,
    # These cause utf8 warnings, see above
    #1307, 1309, 1310, 1311, 1312, 1318, 1320 .. 1323,

    # test errors:    
    892, # ([a-\d]+):-:c:-:False [] range => `-', match=1
    894, # ([\d-z]+):-:cc:$1:False [] range => `-', match=1
    896, # ([\d-\s]+):-:cc:$1:False [] range => `-', match=1
    898, # ([a-[:digit:]]+):-:cc:-:False [] range => `-', match=1
    900, # ([[:digit:]-z]+):-:cc:c:False [] range => `c', match=1
    902, # ([[:digit:]-[:alpha:]]+):-:c:-:False [] range => `-', match=1

    933, # ^(a(b)?)+$:aba:y:-$1-$2-:-a-- => `-a-b-', match=1
    934, # ^(aa(bb)?)+$:aabbaa:y:-$1-$2-:-aa-- => `-aa-bb-', match=1
    939, # ^(a\1?){4}$:aaaaaa:y:$1:aa => `', match=
    997, #TODO (??{}):x:y:-:- => error `Eval-group not allowed at runtime, use re 'eval' in regex m/(??{})/ at (eval 5663) line 1.'
    1088, # ^(<(?:[^<>]+|(?3)|(?1))*>)()(!>!>!>)$:<<!>!>!>><>>!>!>!>:y:$1:<<!>!>!>><>> => `', match=
    1118, # /^(?'main'<(?:[^<>]+|(?&crap)|(?&main))*>)(?'empty')(?'crap'!>!>!>)$/:<<!>!>!>><>>!>!>!>:yM:$+{main}:<<!>!>!>><>> => `', match=

    # XXX: \R doesn't match an utf8::upgraded \x{85}, we need to
    # always convert the subject and pattern to utf-8 for these cases
    # to work
    1370, # (utf8::upgrade($subject)) foo(\R+)bar:foo\r
    1372, # (utf8::upgrade($subject)) (\R+)(\V):foo\r
    1373, # (utf8::upgrade($subject)) foo(\R)bar:foo\x{85}bar:y:$1:\x{85} => `', match=
    1374, # (utf8::upgrade($subject)) (\V)(\R):foo\x{85}bar:y:$1-$2:o-\x{85} => `�-�', match=1
    1386, # (utf8::upgrade($subject)) foo(\v+)bar:foo\r
    1388..1390, # (utf8::upgrade($subject)) (\v+)(\V):foo\r
    1397,1399..1401, # (utf8::upgrade($subject)) foo(\h+)bar:foo\t\x{A0}bar:y:$1:\t\x{A0} => `', match=

    1425, # /^\s*i.*?o\s*$/s:io
    1438, #/\N{}\xe4/i:\xc4:y:$&:\xc4 => error `Unknown charname '' is deprecated. Its use will be fatal in Perl 5.28 at (eval 7892) line 2.'
    1476, # /abc\N {U+41}/x:-:c:-:Missing braces => `-', match=
    1477, # /abc\N {SPACE}/x:-:c:-:Missing braces => `-', match=
    1482, # /\N{U+BEEF.BEAD}/:-:c:-: => `-', match=
    1487, # \c`:-:ac:-:\"\\c`\" is more clearly written simply as \"\\ \" => `-', match=
    1488, # \c1:-:ac:-:\"\\c1\" is more clearly written simply as \"q\" => `-', match=
    1506, # \c?:\x9F:ey:$&:\x9F => `\', match=
    1567, # [\8\9]:\000:Sn:-:- => `-', match=
    1568, # [\8\9]:-:sc:$&:Unrecognized escape \\8 in character class => `[', match=
    1574, # [\0]:-:sc:-:Need exactly 3 octal digits => `-', match=
    1576, # [\07]:-:sc:-:Need exactly 3 octal digits => `-', match=
    1577, # [\07]:7\000:Sn:-:- => `-', match=
    1578, # [\07]:-:sc:-:Need exactly 3 octal digits => `-', match=
    1591, # /\xe0\pL/i:\xc0a:y:$&:\xc0a => `/', match=
    1610, # ^_?[^\W_0-9]\w\z:\xAA\x{100}:y:$&:\xAA\x{100} => `^', match=
    1613, # /s/ai:\x{17F}:y:$&:\x{17F} => `/', match=
    1622, # /[^\x{1E9E}]/i:\x{DF}:Sn:-:- => `-', match=
    1631, # /^\p{L}/:\x{3400}:y:$&:\x{3400} => `�', match=1
    1634, # /[s\xDF]a/ui:ssa:Sy:$&:ssa => `sa', match=1
    1640, # /ff/i:\x{FB00}\x{FB01}:y:$&:\x{FB00} => `/', match=
    1641, # /ff/i:\x{FB01}\x{FB00}:y:$&:\x{FB00} => `/', match=
    1642, # /fi/i:\x{FB01}\x{FB00}:y:$&:\x{FB01} => `/', match=
    1643, # /fi/i:\x{FB00}\x{FB01}:y:$&:\x{FB01} => `/', match=
    1661, # /ffiffl/i:abcdef\x{FB03}\x{FB04}:y:$&:\x{FB03}\x{FB04} => `/', match=
    1662, # /\xdf\xdf/ui:abcdefssss:y:$&:ssss => `/', match=
    1664, # /st/i:\x{DF}\x{FB05}:y:$&:\x{FB05} => `/', match=
    1665, # /ssst/i:\x{DF}\x{FB05}:y:$&:\x{DF}\x{FB05} => `/', match=
    1670, # /[[:lower:]]/i:\x{100}:y:$&:\x{100} => `/', match=
    1671, # /[[:upper:]]/i:\x{101}:y:$&:\x{101} => `/', match=
    1675, # /s\xDF/ui:\xDFs:y:$&:\xDFs => `/', match=
    1676, # /sst/ui:s\N{LATIN SMALL LIGATURE ST}:y:$&:s\N{LATIN SMALL LIGATURE ST} => `/', match=
    1677, # /sst/ui:s\N{LATIN SMALL LIGATURE LONG S T}:y:$&:s\N{LATIN SMALL LIGATURE LONG S T} => `/', match=
    1691, # /[[:alnum:]]/:\x{2c1}:y:-:- => `-', match=
    1693, # /[[:alpha:]]/:\x{2c1}:y:-:- => `-', match=
    1695, # /[[:graph:]]/:\x{377}:y:-:- => `-', match=
    1698, # /[[:lower:]]/:\x{101}:y:-:- => `-', match=
    1700, # /[[:print:]]/:\x{377}:y:-:- => `-', match=
    1703, # /[[:punct:]]/:\x{37E}:y:-:- => `-', match=
    1705, # /[[:upper:]]/:\x{100}:y:-:- => `-', match=
    1707, # /[[:word:]]/:\x{2c1}:y:-:- => `-', match=
    1731, # ^(.)(?:(..)|B)[CX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    1733, # ^(.)(?:BC(.)|B)[CX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    1735, # ^(.)(?:(.)+)*[BX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    1738, # ^(.)(BC)*[BX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    1741, # ^(.)(B)*.[CX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    1785..1787, # (utf8::upgrade($subject)) /[\H]/:\x{BF}:y:$&:\xBF => `�', match=1
    #1786 (utf8::upgrade($subject)) /[\H]/:\x{A0}:n:-:- => false positive
    #1787 (utf8::upgrade($subject)) /[\H]/:\x{A1}:y:$&:\xA1 => `�', match=1
    1796..1799, # \w:\x{200C}:y:$&:\x{200C} => `\', match=
    #1797, # \W:\x{200C}:n:-:- => false positive
    #1798, # \w:\x{200D}:y:$&:\x{200D} => `\', match=
    #1799, # \W:\x{200D}:n:-:- => false positive
    1810..1812, # /^\D{11}/a:\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}:n:-:- => false positive
    1815, # (utf8::upgrade($subject)) \Vn:\xFFn/:y:$&:\xFFn => `�n', match=1
    1822, # a?\X:a\x{100}:y:$&:a\x{100} => `a�', match=1
    1884, # /^\S+=/d:\x{3a3}=\x{3a0}:y:$&:\x{3a3}= => `Σ=', match=1
    1885, # /^\S+=/u:\x{3a3}=\x{3a0}:y:$&:\x{3a3}= => `Σ=', match=1
    1928, # /[a-z]/i:\N{KELVIN SIGN}:y:$&:\N{KELVIN SIGN} => `/', match=
    1929, # /[A-Z]/ia:\N{KELVIN SIGN}:y:$&:\N{KELVIN SIGN} => `/', match=
    1931, # /[A-Z]/i:\N{LATIN SMALL LETTER LONG S}:y:$&:\N{LATIN SMALL LETTER LONG S} => `/', match=
    1937, # /(a+){1}+a/:aaa:n:-:- => false positive
    1956, # \N(?#comment){SPACE}:A:c:-:Missing braces on \\N{} => `-', match=
    1968, # aa$|a(?R)a|a:aaa:y:$&:aaa => `a', match=1
    1983, # /(?xx:[a b])/x:\N{SPACE}:n:-:- => false positive
    1985, # /(?xx)[a b]/x:\N{SPACE}:n:-:- => false positive
  
  );

# older perls:
push @pcre_fail, (645, 651, 654, 664, 931, 1093..1096, 1099..1102,
                1108..1111, 1114, 1116..1117, 1120..1121, 1277,
                1279..1285, 1314, 1316, 1321..1322, 1326,
                  1353, 1356) if $] < 5.014;
push @pcre_fail, (546, 664) if "$]" =~ /^5\.01[46]/;
push @pcre_fail, (621) if "$]" =~ /^5\.01[468]/;
push @pcre_fail, (1939..1942, 1952..1954, 1958..1960, 1963..1966)
                       if "$]" =~ /^5\.020/;
push @pcre_fail, (1952..1954, 1958..1960)
                       if "$]" =~ /^5\.022/;
push @pcre_skip, 544 if $] >= 5.016 and $] < 5.022; # syntax error crashes
push @pcre_skip, 1970..1986 if $] < 5.026; # crashes
push @pcre_fail, 1969 if $] < 5.026; # fixed with 5.26 [perl 128420]
@pcre_fail{@pcre_fail} = ();
@pcre_skip{@pcre_skip} = ();

TEST:
foreach (@tests) {
    $test++;
    if (!/\S/ || /^\s*#/) {
        print "ok $test # (Blank line or comment)\n";
        if (/\S/) { print $_ };
        next;
    }
    #if (/\(\?\{/ || /\(\?\?\{/) {
    #    #but correctly falls back now
    #    print "# (PCRE doesn't support (?{}) or (??{}))\n";
    #    $pcre_fail{$test}++;
    #}
    if (exists $pcre_skip{$test}) {
        print "ok $test # (skip, known to crash with this perl)\n";
        next;
    }
    if ($test >= 1372 && $] < 5.020) {
        print "ok $test # Test too new for $]\n";
        $skip_rest = 1;
        next;
    }
    if ($test >= 1970 && $] < 5.026) {
        print "ok $test # Test too new for $]\n";
        $skip_rest = 1;
        next;
    }
    $skip_rest = 1 if /^__END__$/;

    if ($skip_rest) {
        print "ok $test # (skipping rest)\n";
        next;
    }
    chomp;
    s/\\n/\n/g;
    my ($pat, $subject, $result, $repl, $expect, $reason, $comment) = split(/\t/,$_,7);
    if (!defined $subject) {
        die "Bad test definition on line $test: $_\n";
    }
    $reason = '' unless defined $reason;
    my $input = join(':',$pat,$subject,$result,$repl,$expect);
    $pat = "'$pat'" unless $pat =~ /^[:'\/]/;
    $pat =~ s/(\$\{\w+\})/$1/eeg;
    $pat =~ s/\\n/\n/g;
    $pat = convert_from_ascii($pat) if ord("A") != 65;

    $subject = convert_from_ascii($subject) if ord("A") != 65;
    $subject = eval qq("$subject"); die $@ if $@;

    $expect = convert_from_ascii($expect) if ord("A") != 65;
    $expect  = eval qq("$expect"); die $@ if $@;
    $expect = $repl = '-' if $skip_amp and $input =~ /\$[&\`\']/;

    #my $todo_qr = $qr_embed_thr && ($result =~ s/t//);
    my $skip = ($skip_amp ? ($result =~ s/B//i) : ($result =~ s/B//));
    ++$skip if $result =~ s/M// && !defined &DynaLoader::boot_DynaLoader;
    # regex_sets sS ? those 6 tests are failing
    $result =~ s/[sS]//g;
    if ($result =~ s/a// && ord("A") != 65) {
        $skip++;
        $reason = "Test is only valid for ASCII platforms.  $reason";
    }
    if ($result =~ s/e// && ord("A") != 193) {
        $skip++;
        $reason = "Test is only valid for EBCDIC platforms.  $reason";
    }
    $reason = 'skipping $&' if $reason eq '' && $skip_amp;
    $result =~ s/B//i unless $skip;

    my $todo= $result =~ s/T// ? " # TODO" : "";
    if ($result =~ s/p// or $todo) {
        $pcre_fail{$test}++;
    }
    $todo = " # TODO" if !$todo and $pcre_fail{$test};
    my $testname= $test;
    if ($comment) {
        $comment=~s/^\s*(?:#\s*)?//;
        $testname .= " - $comment" if $comment;
    }

    for my $study ('', 'study $subject', 'utf8::upgrade($subject)',
		   'utf8::upgrade($subject); study $subject') {
	# Need to make a copy, else the utf8::upgrade of an alreay studied
	# scalar confuses things.
        next if $study and ($pcre_fail{$test} or $skip);
	my $subject = $subject;
	my $c = $iters;
	my ($code, $match, $got);
        if ($repl eq 'pos') {
            $code= <<EOFCODE;
                $study;
                pos(\$subject)=0;
                \$match = ( \$subject =~ m${pat}g );
                \$got = pos(\$subject);
EOFCODE
        }
        elsif ($qr_embed) {
            $code= <<EOFCODE;
                my \$RE = qr$pat;
                $study;
                \$match = (\$subject =~ /(?:)\$RE(?:)/) while \$c--;
                \$got = "$repl";
EOFCODE
        }
        else {
            $code= <<EOFCODE;
                $study;
                \$match = (\$subject =~ $OP$pat) while \$c--;
                \$got = "$repl";
EOFCODE
        }
	{
	    # Probably we should annotate specific tests with which warnings
	    # categories they're known to trigger, and hence should be
	    # disabled just for that test
            no warnings qw(uninitialized regexp);
            if ($INC{'re/engine/PCRE2.pm'}) {
                eval "BEGIN { \$^H{regcomp} = re::engine::PCRE2->ENGINE; }; $code"
            } else {
                eval $code; # use perl's engine
            }
	}
	chomp( my $err = $@ );
	if ($result =~ /c/) {
	    if ($err !~ m!^\Q$expect!) {
                # TODO: 6 wrong tests with expecting 'False [] range'
                # Also broken upstream in perl5.
                print "not ok $testname$todo (compile) $input => '$err'\n"; next TEST
            }
	    last;  # no need to study a syntax error
	}
	elsif ( $skip ) {
	    print "ok $test # skipped", length($reason) ? " $reason" : '', "\n";
	    next TEST;
	}
	elsif ($@) {
	    print "not ok $test ";
            print "#TODO " if exists $pcre_fail{$test};
            print "$input => error `$err'\n$code\n"; next TEST;
	}
	elsif ($result =~ /n/) {
	    if ($match) {
              print "not ok $test ";
              print "#TODO " if exists $pcre_fail{$test};
              print "($study) $input => false positive\n";
              next TEST
            }
	}
	else {
	    if (!$match || $got ne $expect) {
                my $s = Data::Dumper->new([$subject],['subject'])->Useqq(1)->Dump;
                my $g = Data::Dumper->new([$got],['got'])->Useqq(1)->Dump;
                print "not ok $test ";
                print "#TODO " if exists $pcre_fail{$test};
                print "($study) $input => `$got', match=$match\n$s\n$g\n$code\n";
                next TEST;
	    }
	}
    }
    print "ok $test\n";
}

1;
