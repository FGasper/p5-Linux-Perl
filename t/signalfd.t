#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::FailWarnings;
use Test::SharedFork;

use Linux::Perl::signalfd;
use Linux::Perl::sigprocmask;

my $sfd = Linux::Perl::signalfd->new(
    signals => ['USR1'],
    flags => ['NONBLOCK'],
);

Linux::Perl::sigprocmask->block('USR1');
my @old = Linux::Perl::sigprocmask->block('USR2');

kill 'USR1', $$;

my $siginfo_hr = $sfd->read();

diag explain $siginfo_hr;

cmp_deeply(
    $siginfo_hr,
    {
          'overrun' => 0,
          'status' => 0,
          'errno' => 0,
          'fd' => 0,
          'pid' => $$,
          'uid' => $>,
          'band' => 0,
          'stime' => 0,
          'code' => 0,
          'ptr' => 0,
          'trapno' => 0,
          'signo' => 10,
          'addr' => 0,
          'tid' => 0,
          'addr_lsb' => 0,
          'int' => 0,
          'utime' => 0,
    },
    'siginfo',
);

$sfd->set_signals('USR2');

kill 'USR2', $$;

$siginfo_hr = $sfd->read();
diag explain $siginfo_hr;

done_testing();
