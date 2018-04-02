package Linux::Perl::eventfd;

=encoding utf-8

=head1 NAME

Linux::Perl::eventfd

=head1 SYNOPSIS

    my $efd = Linux::Perl::eventfd->new(
        initval => 4,
        flags => [ 'NONBLOCK', 'CLOEXEC' ], #only on 2.6.27+
    );

    #or, e.g., Linux::Perl::eventfd::x86_64

    my $fd = $efd->fileno();

    $efd->add(12);

    my $read = $efd->read();

=head1 DESCRIPTION

This is an interface to the C<eventfd>/C<eventfd2> system call.

=cut

use strict;
use warnings;

use Module::Load;

use Linux::Perl;
use Linux::Perl::Constants;
use Linux::Perl::Endian;

use constant {
    PERL_CAN_64BIT => !!do { local $@; eval { pack 'Q', 1 } },
};

=head1 METHODS

=head2 I<CLASS>->new( %OPTS )

%OPTS is:

=over

=item * C<initval> - Optional, as described in the eventfd documentation.
Defaults to 0.

=item * C<flags> - Optional, an array reference of one or both of:
C<NONBLOCK>, C<CLOEXEC>, C<SEMAPHORE>. See the eventfd documentation for
more details.

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $arch_module = $class->can('NR_eventfd') && $class;
    $arch_module ||= do {
        require Linux::Perl::ArchLoader;
        Linux::Perl::ArchLoader::get_arch_module($class);
    };

    my $initval = 0 + ( $opts{'initval'} || 0 );

    my $flags = 0;
    if ( $opts{'flags'} ) {
        for my $fl ( @{ $opts{'flags'} } ) {
            my $val_cr = $arch_module->can("flag_$fl") or do {
                die "unknown flag: “$fl”";
            };
            $flags |= $val_cr->();
        }
    }

    my $call = 'NR_' . ($flags ? 'eventfd2' : 'eventfd');

    my $fd = Linux::Perl::call( 0 + $arch_module->$call(), $initval, $flags || () );

    open my $fh, '+<&=' . $fd;

    return bless [$fh], $arch_module;
}

=head2 I<OBJ>->fileno()

Returns the file descriptor number.

=cut

sub fileno { fileno $_[0][0] }

=head2 $val = I<OBJ>->read()

Reads a value from the eventfd instance. Sets C<$!> and returns undef
on error.

=cut

my ($big, $low);

sub read {
    return undef if !sysread $_[0][0], my $buf, 8;

    if (PERL_CAN_64BIT) {
        ($big, $low) = (0, unpack('Q', $buf));
    }
    else {
        if (Linux::Perl::Endian::SYSTEM_IS_BIG_ENDIAN) {
            ($big, $low) = unpack 'NN', $buf;
        }
        else {
            ($low, $big) = unpack 'VV', $buf;
        }

        #TODO: Need to test what happens on a 32-bit Perl.
        die "No 64-bit support! (high=$big, low=$low)" if $big;
    }

    return $low;
}

=head2 I<OBJ>->add( NUMBER )

Adds NUMBER to the counter.

=cut

my $packed;

sub add {
    if (PERL_CAN_64BIT) {
        $packed = pack 'Q', $_[1];
    }
    elsif (Linux::Perl::Endian::SYSTEM_IS_BIG_ENDIAN) {
        $packed = pack 'x4N', $_[1];
    }
    else {
        $packed = pack 'Vx4', $_[1];
    }

    return syswrite( $_[0][0], $packed ) && 1;
}

1;
