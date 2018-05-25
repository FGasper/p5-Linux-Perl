#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('getdents');

use Test::Deep;
use Test::More;
use Test::SharedFork;

use Linux::Perl::getdents;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::getdents';
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

    note "$class (PID $$)";

    my $dir = File::Temp::tempdir( CLEANUP => 1);

    do { open my $fh, '>', "$dir/foo" };
    do { open my $fh, '>', "$dir/bar" };
    do { open my $fh, '>', "$dir/baz" };

    opendir( my $dh, $dir );
    my @nodes = readdir $dh;
    rewinddir $dh;

    my @dents = $class->getdents($dh, 32768);

    cmp_deeply(
        \@dents,
        superbagof(
            {
                ino => re( qr<\A[0-9]+\z> ),
                off => re( qr<\A[0-9]+\z> ),
                type => $class->DT_DIR(),
                name => '.',
            },
            {
                ino => re( qr<\A[0-9]+\z> ),
                off => re( qr<\A[0-9]+\z> ),
                type => $class->DT_DIR(),
                name => '..',
            },
        ),
        'response includes expected “.” and “..” entries',
    ) or diag explain \@dents;

    cmp_deeply(
        \@dents,
        bag( map { superhashof( { name => $_ } ) } @nodes ),
        'response includes all entries',
    );

    return;
}

