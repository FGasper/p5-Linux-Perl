#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;
use Test::Deep;

use Linux::Perl::MsgHdr;

use Data::Dumper;
sub _rightdump {
    local $Data::Dumper::Useqq = 1;
    local $Data::Dumper::Indent = 0;
    Dumper(@_);
}

my $cmsg = Linux::Perl::MsgHdr::pack_control( [ 1, 2, 'abcdef' ] );
my $lvl_type_data = pack( 'i! i! a8', 1, 2, 'abcdef' );
my $expected_cmsg = pack( 'L! a*', length(pack 'L!') + length($lvl_type_data) - 2, $lvl_type_data );
is(
    $cmsg,
    $expected_cmsg,
    'pack_control() - one value',
) or diag _rightdump([ $cmsg, $expected_cmsg ]);

$cmsg = Linux::Perl::MsgHdr::pack_control( [ 1, 2, 'abcdef', 3, 4, 'ghijk' ] );

my $ltd2 = pack( 'i! i! a8', 3, 4, 'ghijk' );
is(
    $cmsg,
    join(
        q<>,
        $expected_cmsg,
        pack( 'L! a*', length(pack 'L!') + length($ltd2) - 3, $ltd2 ),
    ),
    'pack_control() - two values',
) or diag _rightdump($cmsg);

#----------------------------------------------------------------------

my %pack_opts = (
    name => \'123123',
    iov => [ \'abcdefg', \'hijklmnop' ],
    control => [ -1, -2, '3456789' ],
);

my $pieces_ar = Linux::Perl::MsgHdr::pack_msghdr(\%pack_opts);

my $main_pack = pack(
    'P L! P L! P L! x[I!]',

    ${ $pack_opts{'name'} },
    length ${ $pack_opts{'name'} },

    ${ $pieces_ar->[1] },
    0 + @{ $pack_opts{'iov'} },

    ${ $pieces_ar->[2] },

    # The total length of the control segment, including padding.
    length( pack 'L!i!i!' ) + length($pack_opts{'control'}[2]) + 1,
);

is(
    ${ $pieces_ar->[0] },
    $main_pack,
    'main msghdr pack',
) or diag _rightdump( [ ${ $pieces_ar->[0] }, $main_pack ] );

is(
    ${ $pieces_ar->[1] },
    pack(
        'P L! P L!',

        ${ $pack_opts{'iov'}[0] },
        length ${ $pack_opts{'iov'}[0] },

        ${ $pack_opts{'iov'}[1] },
        length ${ $pack_opts{'iov'}[1] },
    ),
    'iov pack',
);

my $ctrl_pack = pack(
    'L! i! i! a* x![I!]',

    # The length of the first message, minus end-padding.
    length( pack 'L!i!i!' ) + length($pack_opts{'control'}[2]),

    @{ $pack_opts{'control'} }[ 0, 1 ],
    $pack_opts{'control'}[2],
);

is(
    ${ $pieces_ar->[2] },
    $ctrl_pack,
    'control pack',
) or diag _rightdump( ${ $pieces_ar->[2] }, $ctrl_pack );

#----------------------------------------------------------------------

done_testing();

1;
