package Linux::Perl::sendmsg::x86_64;

use strict;
use warnings;

use parent 'Linux::Perl::sendmsg';

use constant {
    NR_sendmsg => 46,
};

1;
