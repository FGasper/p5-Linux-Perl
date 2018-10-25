package Linux::Perl::prlimit::x86_64;

use strict;
use warnings;

use parent 'Linux::Perl::prlimit';

use constant {
    _NR_prlimit64 => 302,
};

1;
