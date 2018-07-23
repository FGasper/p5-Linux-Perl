package Linux::Perl::getrandom;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Linux::Perl::getrandom

=head1 SYNOPSIS

    my $numbytes = Linux::Perl::getrandom::x86_64->getrandom(
        buffer => \$buffer,
        flags => [ 'RANDOM', 'NONBLOCK' ],
    );

    # … or, platform-neutral:
    my $numbytes = Linux::Perl::getrandom->getrandom(
        buffer => \$buffer,
        flags => [ 'RANDOM', 'NONBLOCK' ],
    );

=head1 DESCRIPTION

This is an interface to the C<getrandom> system call. This system
call is available B<only> in kernel 3.17 and after.

=cut

use Linux::Perl::Pointer;

my %FLAG_VALUE = (
    NONBLOCK => 1,
    RANDOM => 2,
);

sub getrandom {
    my ($class, %opts) = @_;

    if (!$class->can('NR_getrandom')) {
        require Linux::Perl::ArchLoader;
        $class = Linux::Perl::ArchLoader::get_arch_module($class);
    }

    my $flags = 0;
    if ($opts{'flags'}) {
        for my $f ( @{ $opts{'flags'} } ) {
            $flags |= $FLAG_VALUE{$f} || do {
                die "Invalid flag: “$f”!";
            };
        }
    }

    if ('SCALAR' ne ref $opts{'buffer'}) {
        die "“buffer” must be a scalar reference, not “$opts{'buffer'}”!";
    }

    return Linux::Perl::call(
        $class->NR_getrandom(),
        Linux::Perl::Pointer::get_address( ${ $opts{'buffer'} } ),
        length( ${ $opts{'buffer'} } ),
        0 + $flags,
    );
}

1;
