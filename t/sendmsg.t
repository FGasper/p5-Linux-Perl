#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('sendmsg');

use Test::More;
use Test::FailWarnings -allow_deps => 1;
use Test::SharedFork;
use Test::Exception;

use Socket;

use Linux::Perl::sendmsg;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::sendmsg';
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

    socketpair my $yin, my $yang, Socket::AF_UNIX(), Socket::SOCK_STREAM(), 0;

    $class->new( iov => [ \'hello' ] )->sendmsg($yin);

    sysread( $yang, my $buf, 5 );
    is( $buf, 'hello', 'sent plain message' );

    lives_ok(
        sub {
            $class->new(
                iov => [ \'0' ],
                control => [ Socket::SOL_SOCKET(), Socket::SCM_CREDENTIALS(), \pack( "I!*", $$, $>, (split m< >, $))[0] ) ],
                flags => ['NOSIGNAL'],
            )->sendmsg($yin);
        },
        'sending SCM_CREDENTIALS',
    );

    lives_ok(
        sub {
            $class->new(
                iov => [ \'0' ],
                control => [ Socket::SOL_SOCKET(), Socket::SCM_RIGHTS(), \pack( "I!*", fileno(\*STDOUT) ) ],
                flags => ['NOSIGNAL'],
            )->sendmsg($yin);
        },
        'sending SCM_RIGHTS',
    );
}
