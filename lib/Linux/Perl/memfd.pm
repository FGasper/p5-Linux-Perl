package Linux::Perl::memfd;

use strict;
use warnings;

use Linux::Perl;
use Linux::Perl::ParseFlags;

use constant {
    _flag_CLOEXEC => 1,
    _flag_ALLOW_SEALING => 2,

    _MAX_NAME_LENGTH => 249,

    _hugetlb_flag => 4,
    _hugetlb_flag_encode_shift => 26,
    _hugetlb_size_num => {
        '64KB' => 16,
        '512KB' => 19,
        '1MB' => 20,
        '2MB' => 21,
        '8MB' => 23,
        '16MB' => 24,
        '256MB' => 28,
        '1GB' => 30,
        '2GB' => 31,
        '16GB' => 34,
    },
};

sub new {
    my ($class, %opts) = @_;

    local ($!, $^E);

    my $arch_module = $class->can('NR_memfd_create') && $class;
    $arch_module ||= do {
        require Linux::Perl::ArchLoader;
        Linux::Perl::ArchLoader::get_arch_module($class);
    };

    if ($opts{'name'}) {
        if ($opts{'name'} =~ tr<\0><>) {
            die "'name' cannot contain NUL bytes!";
        }

        if (length($opts{'name'}) > _MAX_NAME_LENGTH()) {
            die sprintf( "'name' (%d bytes) cannot exceed %d bytes.", length($opts{'name'}), _MAX_NAME_LENGTH() );
        }
    }
    elsif (!defined $opts{'name'}) {
        $opts{'name'} = q<>;
    }

    my $flags = Linux::Perl::ParseFlags::parse($arch_module, $opts{'flags'});

    if ( my $huge = $opts{'huge_page_size'} ) {
        if ($flags & _flag_ALLOW_SEALING()) {
            die "Huge page sizes cannot be used with ALLOW_SEALING!";
        }

        my $page_size_num = _hugetlb_size_num()->{$huge} or do {
            die "Unknown huge page size: $huge\n";
        };

        $flags |= (0 + _hugetlb_flag()) | ($page_size_num << _hugetlb_flag_encode_shift());
    }

    my $fd = Linux::Perl::call(
        $arch_module->NR_memfd_create(),
        $opts{'name'},
        0 + $flags,
    );

    #Force CLOEXEC if the flag was given.
    #local $^F = 0 if $flags & $arch_module->_flag_CLOEXEC();

    open my $fh, '+<&=' . $fd;

    return bless $fh, $arch_module;
}

1;
