#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('prlimit');

use Test::More;
use Test::FailWarnings -allow_deps => 1;
use Test::SharedFork;

use Linux::Perl::prlimit;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::prlimit';
            if (!$generic_yn) {
                require Linux::Perl::ArchLoader;
                $class = Linux::Perl::ArchLoader::get_arch_module($class);
            };

            diag "class: $class";
            _do_tests($class);
        };
        die if $@;
        exit;
    }
}

done_testing();

#----------------------------------------------------------------------

sub _do_tests {
    my ($class) = @_;

    my $resnum = $class->NUMBER()->{'MSGQUEUE'};

    my @lims1 = eval {
        $class->get(0, $resnum);
    };
    if (!@lims1 && $@->get('error') == Errno::ENOSYS()) {
        diag "This kernel lacks prlimit support.";

        ok 1;   #placeholder assertion so that we haven’t “skipped”

        return;
    }

    my @lims2 = $class->set(0, $resnum, 54, 65);

    is( "@lims2", "@lims1", 'set() matches prior get()' );

    my @lims3 = $class->set(0, $resnum, 43, 54);

    is( "@lims3", '54 65', 'set() output matches input to prior set()' );

    pipe( my $ready_r, my $ready_w );

    pipe( my $p_ready_r, my $p_ready_w );

    my $pid = fork or do {
        close $ready_r;
        close $p_ready_w;

        my @old = $class->set(0, $resnum, 11, 22);

        syswrite($ready_w, "@old\n");
        readline $p_ready_r;
        close $p_ready_r;

        @old = $class->get(0, $resnum);
        syswrite($ready_w, "@old\n");

        exit;
    };

    close $ready_w;
    close $p_ready_r;

    readline $ready_r;

    my @lims4 = $class->get( $pid, $resnum );

    is( "@lims4", '11 22', 'read other process’s rlimit' );

    $class->set( $pid, $resnum, 10, 20 );

    print {$p_ready_w} "\n";
    close $p_ready_w;

    my @lims6 = split m<\s+>, readline $ready_r;
    is( "@lims6", '10 20', 'set other process’s rlimit' );

    waitpid $pid, 0;

    return;
}

