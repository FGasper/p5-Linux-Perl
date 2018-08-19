package Linux::Perl::epoll;

use strict;
use warnings;

use Linux::Perl::Constants::Fcntl;
use Linux::Perl::ParseFlags;

*_flag_CLOEXEC = \*Linux::Perl::Constants::Fcntl::flag_CLOEXEC;

sub new {
    my ($class, %opts) = @_;

    local ($!, $^E);

    my $arch_module = $class->can('NR_eventfd') && $class;
    $arch_module ||= do {
        require Linux::Perl::ArchLoader;
        Linux::Perl::ArchLoader::get_arch_module($class);
    };

    my $flags = Linux::Perl::ParseFlags::parse( $opts{'flags'} );

    my $call_name = 'NR_epoll_create';

    my $fd;

    if ($flags)) {
        $call_name .= '1';

        $fd = Linux::Perl::call( $arch_module->$call_name(), 0 + $flags );
    }
    else {
        $opts{'size'} ||= 1;

        $fd = Linux::Perl::call( $arch_module->$call_name(), 0 + $opts{'size'} );
    }

    #Force CLOEXEC if the flag was given.
    local $^F = 0 if $flags & _flag_CLOEXEC();

    open my $fh, '+<&=' . $fd;

    return bless [$fh], $arch_module;
}
