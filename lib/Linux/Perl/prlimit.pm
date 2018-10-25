package Linux::Perl::prlimit;

=encoding utf-8

=head1 NAME

Linux::Perl::prlimit

=head1 SYNOPSIS

    my ($soft, $hard) = Linux::Perl::prlimit->get(
        0,
        Linux::Perl::prlimit::NUMBER()->{'NPROC'}
    );

    my ($old_soft, $old_hard) = Linux::Perl::prlimit->get(
        0,
        Linux::Perl::prlimit::NUMBER()->{'NPROC'},
        $new_soft,
        $new_hard,
    );

=head1 DESCRIPTION

This module provides access to Linux’s facility for getting and setting
an arbitrary process’s rlimits.

=cut

use strict;
use warnings;

use Call::Context;
use Linux::Perl;

use parent (
    'Linux::Perl::Base',
    'Linux::Perl::Base::BitsTest',
);

#----------------------------------------------------------------------

=head1 CONSTANTS

=head2 INFINITY

Equivalent to the kernel’s RLIM_INFINITY constant.

=cut

use constant INFINITY => ~0;

=head2 NAMES

A list of resource names, e.g., C<CPU>. (cf. C<man 2 prlimit>)

=cut

use constant NAMES => qw(
    CPU
    FSIZE
    DATA
    STACK
    CORE
    RSS
    NPROC
    NOFILE
    MEMLOCK
    AS
    LOCKS
    SIGPENDING
    MSGQUEUE
    NICE
    RTPRIO
    RTTIME
);

=head2 NUMBER

A reference to a hash that correlates resource name (e.g., C<FSIZE>) to number.

=cut

use constant NUMBER => { map { ( (NAMES)[$_] => $_ ) } 0 .. (NAMES - 1) };

use constant _TMPL => (__PACKAGE__->_PACK_u64() x 2);

#----------------------------------------------------------------------

=head1 METHODS

=head2 ($soft, $hard) = I<CLASS>->get( $PID, $RESOURCE_NUM )

Fetches an individual resource limit. Must be called in list context.

=cut

sub get {
    my ($class, $pid, $resource) = @_;

    Call::Context::must_be_list();

    my $old = pack _TMPL();

    return $class->_prlimit64($pid, $resource, \undef, \$old);
}

=head2 ($old_soft, $old_hard) = I<CLASS>->set( $PID, $RESOURCE_NUM, $SOFT, $HARD )

Sets an individual resource limit. If called in list context
will return the old soft/hard limits. Must not be called in
scalar context.

=cut

sub set {
    my ($class, $pid, $resource, $soft, $hard) = @_;

    my $old = pack _TMPL();

    if (defined wantarray) {
        Call::Context::must_be_list();
    }

    my $new = pack _TMPL(), $soft, $hard;

    return $class->_prlimit64($pid, $resource, \$new, \$old);
}

sub _prlimit64 {
    my ($class, $pid, $resource, $new_sr, $old_sr) = @_;

    $class = $class->_get_arch_module();

    Linux::Perl::call( $class->NR_prlimit64(), 0 + $pid, 0 + $resource, $$new_sr, $$old_sr );

    return wantarray ? unpack( _TMPL(), $$old_sr ) : ();
}

1;
