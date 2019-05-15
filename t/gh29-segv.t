local $/;
print "1..2\n";
use re::engine::PCRE2;
# with PCRE2 10.30-RC1 built with --enable-jit-sealloc

"Hello, world" !~ /(?<=Moose|Mo), (world)/;
"Hello, world" =~ /(?<=Hello|Hi), (world)/;
my $pid = fork;

if ($pid) {
    print "not" if $pid != waitpid($pid, 0) or $?;
    print "ok 2\n"
} else {
    print "ok 1\n";
}
