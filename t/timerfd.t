#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('timerfd');

use File::Temp;

use Test::More;
use Test::Deep;
use Test::FailWarnings;
use Test::SharedFork;

use Linux::Perl::timerfd;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::timerfd';
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

sub _do_tests {
    my ($class) = @_;

    note "Using class: $class (PID $$)";

    my $obj = $class->new( clockid => 'REALTIME' );
    ok( $obj->fileno(), 'fileno()' );

    my @old = $obj->settime( value => 0.1, interval => 0.1 );

    cmp_deeply( \@old, [0, 0], 'settime() list return' );

    vec( my $rin = q<>, $obj->fileno(), 1 ) = 1;

    is( $obj->read(), 1, 'read() - blocking' );
    is( $obj->read(), 1, 'read() - blocking (again)' );

    #----------------------------------------------------------------------

    $obj = $class->new(
        clockid => 'REALTIME',
        flags => ['NONBLOCK'],
    );

    my $read_val = $obj->read();
    my $err = $!;
    is( $read_val, undef, 'read() - non-blocking' );

    {
        local $! = $err;
        ok( $!{'EAGAIN'}, '... and the error is as expected' );
    }

    #----------------------------------------------------------------------

    {
        local $^F = 1000;

        my ($tfh, $tfile) = File::Temp::tempfile( CLEANUP => 1 );

        my $obj = $class->new( clockid => 'REALTIME' );
        my $fileno = $obj->fileno();

        my $no_cloexec = `$^X -e'print readlink "/proc/self/fd/$fileno"'`;
        ok( $no_cloexec, 'no CLOEXEC if $^F is set high' );

        $obj = $class->new(
            clockid => 'REALTIME',
            flags => ['NONBLOCK', 'CLOEXEC'],
        );
        $no_cloexec = `$^X -e'print readlink "/proc/self/fd/$fileno"'`;
        ok( !$no_cloexec, 'CLOEXEC if $^F is high but CLOEXEC is passed' );
    }

    SKIP: {
        my $obj = $class->new( clockid => 'REALTIME' );

        $obj->set_ticks(23) or do {
            skip "set_ticks() does not work.", 1;
        };

        is( $obj->read(), 23, 'set_ticks() worked as expected' );
    }
}

done_testing();
