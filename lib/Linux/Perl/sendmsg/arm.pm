package Linux::Perl::sendmsg::arm;

use strict;
use warnings;

use parent 'Linux::Perl::sendmsg';

use constant {
    NR_sendmsg => 296,
};

1;
