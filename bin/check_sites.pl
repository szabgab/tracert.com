#!/usr/bin/perl
use strict;
use warnings;

use Cwd qw(abs_path);

use lib 'lib';

use Tracert;
Tracert->new(root => abs_path('.'))->check_sites;


