#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('fanotify');

use File::Temp;
use File::Slurp;

use Test::More;
use Test::Deep;
use Test::FailWarnings -allow_deps => 1;
use Test::SharedFork;

use Socket;

use Linux::Perl::fanotify;

plan skip_all => 'Must run privileged!' if $>;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::fanotify';
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

    my $fan = $class->new( access => 'RDONLY' );

    $fan->flush_mount_marks();
    $fan->flush_non_mount_marks();

    $fan->add_mark(
        pathname => $^X,
        events => ['OPEN'],
    );

    my ($fh, $fpath) = File::Temp::tempfile( CLEANUP => 1 );

    unlink $fpath;

    $fan->add_mark(
        events => ['CLOSE'],
        fh => $fh,
    );

    my $fd = fileno $fh;

    close $fh;

    my @events = $fan->read();

    cmp_deeply(
        \@events,
        [
            {
                fd => $fd,
                pid => $$,
                mask => $fan->EVENT()->{'CLOSE_WRITE'},
            },
        ],
        'close event recorded',
    ) or diag explain \@events;
}

done_testing();
