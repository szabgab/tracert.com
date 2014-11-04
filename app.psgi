#!/usr/bin/perl
use strict;
use warnings;

use lib 'lib';
use Tracert::Web;

my $app = Tracert::Web->run;
