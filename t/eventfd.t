#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Errno;
use IO::File;

use Test::More;
use Test::SharedFork;

use Linux::Perl::eventfd;

plan tests => 5 * 2;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::eventfd';
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

    my $efd = $class->new( initval => 5 );
    
    ok( $efd->fileno(), 'fileno()' );
    
    $efd->add(4);
    $efd->add(2);
    
    is( $efd->read(), 11, 'initval, add, read' );
    
    open my $dup, '+<&=' . $efd->fileno();
    $dup->blocking(0);
    
    my $got = $efd->read();
    my $err = $!;
    is( $got, undef, '... after which there is nothing there' );
    is( 0 + $err, Errno::EAGAIN(), '... and $! is EAGAIN' );
    
    SKIP: {
        skip 'No 64-bit support!', 1 if !eval { pack 'Q', 1 };
    
        $efd->add( 1 + (2**33) );
        $efd->add(3);
    
        is( $efd->read(), 4 + (2**33), 'add() and read() 64-bit' )
    }

    return;
}
