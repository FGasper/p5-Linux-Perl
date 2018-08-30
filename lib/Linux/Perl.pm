package Linux::Perl;

=encoding utf-8

=head1 NAME

Linux::Perl - Linux system calls with pure Perl

=head1 SYNOPSIS

    my $efd = Linux::Perl::eventfd->new();

    #...or, if you know your architecture:
    my $efd = Linux::Perl::eventfd::x86_64->new();

=head1 DESCRIPTION

In memory-sensitive environments it is useful to minimize the number
of XS modules that Perl loads. Oftentimes the CPAN modules that implement
support for various Linux system calls, though, will bring in XS for the
sake of writing platform-neutral code.

Linux::Perl accommodates use cases where platform neutrality is less of
a concern than minimizing memory usage.

=head1 MODULES

Each family of system calls lives in its own namespace under C<Linux::Perl>:

=over

=item * L<Linux::Perl::epoll>

=item * L<Linux::Perl::inotify>

=item * L<Linux::Perl::eventfd>

=item * L<Linux::Perl::getrandom>

=item * L<Linux::Perl::timerfd>

=item * L<Linux::Perl::memfd>

=item * L<Linux::Perl::signalfd>

=item * L<Linux::Perl::sigprocmask>

=item * L<Linux::Perl::aio>

=item * L<Linux::Perl::uname>

=item * L<Linux::Perl::getdents>

=item * L<Linux::Perl::mq>

=back

The distribution contains a number of other modules, none of which is
currently intended for outside use.

=head1 PLATFORM-SPECIFIC INVOCATION

Each Linux::Perl system call implementation can be called with a
platform-neutral syntax as well as with a platform-specific one;
for example:

    my $efd = Linux::Perl::eventfd->new();

    my $efd = Linux::Perl::eventfd::x86_64->new();

The platform-specific call is a bit lighter because it avoids loading
L<Config> to determine the current platform.

=head1 PLATFORM SUPPORT

C<x86_64> and C<arm> are the best-supported platforms. Limited support
is included for C<i686> and C<i386>.

Support for adding new platforms just involves adding new modules with the
necessary constants to the distribution.

Note also that a 64-bit Perl is generally assumed.

=cut

use strict;
use warnings;

use Linux::Perl::X ();

our $VERSION = '0.13-TRIAL1';

our @_TOLERATE_ERRNO;

sub call {
    local $!;
    my $ok = syscall(0 + $_[0], @_[1 .. $#_]);
    if ($ok == -1 && !grep { $_ == $! } @_TOLERATE_ERRNO) {
        die Linux::Perl::X->create('Call', $_[0], $!);
    }

    return $ok;
}

=head1 REPOSITORY

L<https://github.com/FGasper/p5-Linux-Perl>

=head1 AUTHOR

Felipe Gasper (FELIPE)

=head1 COPYRIGHT

Copyright 2018 by L<Gasper Software Consulting|http://gaspersoftware.com>

=head1 LICENSE

This distribution is released under the same license as Perl.

=cut

1;
