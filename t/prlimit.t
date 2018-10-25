#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('prlimit64');

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

    my @lims1 = $class->get(0, $class->NUMBER()->{'NPROC'});

    my @lims2 = $class->set(0, $class->NUMBER()->{'NPROC'}, 1234, 2345);

    is( "@lims2", "@lims1", 'set() matches prior get()' );

    my @lims3 = $class->set(0, $class->NUMBER()->{'NPROC'}, 2345, 3456);

    is( "@lims2", '1234 2345', 'set() output matches input to prior set()' );

    pipe( my $ready_r, my $ready_w );

    local $SIG{'INT'} = sub {};

    my $pid = fork or do {
        close $ready_r;

        my @old = $class->set(0, $class->NUMBER()->{'NPROC'}, 1111, 2222);

        syswrite($ready_w, "@old\n");
        sleep;

        @old = $class->get(0, $class->NUMBER()->{'NPROC'});
        syswrite($ready_w, "@old\n");

        exit;
    };

    close $ready_w;

    readline $ready_r;

    my @lims4 = $class->get( $pid, $class->NUMBER()->{'NPROC'} );

    is( "@lims4", '1111 2222', 'read other process’s rlimit' );

    $class->set( $pid, $class->NUMBER()->{'NPROC'}, 1122, 2233 );

    kill 'INT', $pid;

    my @lims6 = split m<\s+>, readline $ready_r;
    is( "@lims6", '1122 2233', 'set other process’s rlimit' );

    return;
}

