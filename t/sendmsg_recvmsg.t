#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use Data::Dumper;

use Linux::Perl::sendmsg;
use Linux::Perl::recvmsg;

use Socket;
use Carp::Always;

sub _rightdump {
    local $Data::Dumper::Useqq = 1;
    local $Data::Dumper::Indent = 0;
    return Dumper(@_);
}

socketpair my $yin, my $yang, Socket::AF_UNIX, Socket::SOCK_DGRAM, 0;

my $data1 = join( q<>, 'a' .. 'z' );
my $data2 = join( q<>, 0 .. 9 );

my $control_ar = [
    Socket::SOL_SOCKET(),
    Socket::SCM_CREDENTIALS(),
    pack( 'I!*', $$, $>, (split m< >, $) )[0] ),
];

my $smsg = Linux::Perl::sendmsg->new(
    iov => [ \$data1, \$data2 ],
    control => $control_ar,
);
$smsg->sendmsg($yin);

#diag explain $smsg;

setsockopt( $yang, Socket::SOL_SOCKET(), Socket::SO_PASSCRED(), 1 );

my $rmsg = Linux::Perl::recvmsg->new(
    iovlen => [ 1024 ],
    controllen => [ 12 ],
);

my $bytes = $rmsg->recvmsg($yang);

#diag _rightdump( $rmsg );
#diag _rightdump( $rmsg->get_iov() );

is(
    ${ $rmsg->get_iov()->[0] },
    join( q<>, 'a' .. 'z', 0 .. 9 ),
    'payload received',
) or diag _rightdump( $rmsg->get_iov() );

is_deeply(
    $rmsg->get_control(),
    [
        Socket::SOL_SOCKET(),
        Socket::SCM_CREDENTIALS(),
        pack( 'I!*', $$, $>, (split m< >, $) )[0] ),
    ],
    'control received',
) or diag _rightdump( $rmsg->get_control() );

#----------------------------------------------------------------------

#socketpair $yin, my $yang, Socket::AF_UNIX, Socket::SOCK_DGRAM, 0;

pipe my $r, my $w;

$smsg->set_iov( \do { 'a' .. 'z' } );

$smsg->set_control(
    Socket::SOL_SOCKET(), Socket::SCM_RIGHTS(),
    pack( 'I!', fileno $r),

    Socket::SOL_SOCKET(), Socket::SCM_RIGHTS(),
    pack( 'I!', fileno $w),
);

#diag _rightdump($smsg);
$smsg->sendmsg($yin);

$rmsg->set_iovlen( 1024 );
$rmsg->set_controllen( 12, 12 );

$bytes = $rmsg->recvmsg($yang);

my @passed_fds;

my @control = @{ $rmsg->get_control() };
while (@control) {
    if ($control[1] == Socket::SCM_RIGHTS()) {
        push @passed_fds, unpack 'I!*', $control[2];
        #diag sprintf( 'Received FDs: %v.02x', $control[2] );
    }
    elsif ($control[1] != Socket::SCM_CREDENTIALS()) {
        diag sprintf( 'Received unexpected control: [ %d, %d, %v.02x ]', @control[0, 1, 2] );
    }

    splice( @control, 0, 3 );
}

is(
    0 + @passed_fds,
    2,
    'two FDs passed',
) or diag _rightdump( $rmsg->get_control() );

open my $r2, '<&=', $passed_fds[0];
open my $w2, '>&=', $passed_fds[1];

is_deeply(
    [ stat $r2 ],
    [ stat $r ],
    'duplicated read filehandle matches original',
);

is_deeply(
    [ stat $w2 ],
    [ stat $w ],
    'duplicated write filehandle matches original',
);

syswrite( $w, 'a' );
sysread( $r2, my $buf, 1 );
is( $buf, 'a', 'send from original write to duplicated read' );

syswrite( $w2, 'z' );
sysread( $r, $buf, 1 );
is( $buf, 'z', 'send from duplicated write to original read' );

#----------------------------------------------------------------------

socketpair $yin, $yang, Socket::AF_UNIX, Socket::SOCK_DGRAM, 0;

setsockopt( $yang, Socket::SOL_SOCKET(), Socket::SO_PASSCRED(), 1 );

syswrite( $yin, "\0" );

$rmsg = Linux::Perl::recvmsg->new(
    iovlen => [ 1024 ],
    controllen => [ 12 ],
);

$bytes = $rmsg->recvmsg($yang);

done_testing();
