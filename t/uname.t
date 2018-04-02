#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::SharedFork;

use Linux::Perl::uname;

plan tests => 3 * 2;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::uname';
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

    diag "$class (PID $$)";

    my @resp = $class->uname();

    cmp_ok( 0 + @resp, '>=', 5, 'minimum number of strings' );
    cmp_ok( 0 + @resp, '<=', 6, 'maximum number of strings' );

    is( $resp[0], 'Linux', 'We know the OS. :)' );

    return;
}
