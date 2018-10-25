package Linux::Perl::prlimit;

use strict;
use warnings;

use Call::Context;
use Linux::Perl;

use parent 'Linux::Perl::Base';

use constant INFINITY => ~0;

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

use constant NUMBER => { map { ( (NAMES)[$_] => $_ ) } 0 .. (NAMES - 1) };

use constant _TMPL => 'L!L!';

sub get {
    my ($class, $pid, $resource) = @_;

    Call::Context::must_be_list();

    $class = $class->_get_arch_module();

    my $buf = pack _TMPL();

    Linux::Perl::call( $class->_NR_prlimit64(), 0 + $pid, 0 + $resource, undef, $buf );

    return unpack _TMPL(), $buf;
}

sub set {
    my ($class, $pid, $resource, $soft, $hard) = @_;

    my $old;

    if (defined wantarray) {
        Call::Context::must_be_list();

        $old = pack _TMPL();
    }

    my $new = pack _TMPL(), $soft, $hard;

    $class->_prlimit64($pid, $resource, \$new, \$old);

    return wantarray ? unpack( _TMPL(), $old ) : ();
}

sub _prlimit64 {
    my ($class, $pid, $resource, $new_sr, $old_sr) = @_;

    $class = $class->_get_arch_module();

    return Linux::Perl::call( $class->_NR_prlimit64(), 0 + $pid, 0 + $resource, $$new_sr, $$old_sr );
}

1;
