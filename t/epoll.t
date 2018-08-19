#!/usr/bin/env perl

use strict;
use warnings;

BEGIN { eval 'use autodie' }

pipe( my $r, my $w );

use Linux::Perl::epoll;
