#! /usr/bin/env perl

use strict;
use warnings;

# parse race grid from text file

my $data_dir  = 'data/src/';
my $grid_txt  = 'aus-race-grid.txt';
my $path      = $data_dir . $grid_file;
my $grid_pdf  = "$ENV{HOME}/Documents/F1/aus-race-grid.pdf";
use constant PDFTOTEXT => '/usr/local/bin/pdftotext';

#open GRID, "<", $path
#  or die "Unable to open file $path: $!\n";

open GRID, "PDFTOTEXT -layout $grid_pdf - |"
  or die "unable to open PDFTOTEXT: $!";

my $name_re    = q#[A-Z]\. [A-Z '-]+#;
my $time_re    = '\d:\d\d\.\d\d\d';
my $entrant_re = '[\w &]+';
my $pos_re     = '\d{1,2}';
my $no_re      = $pos_re;

my $odd  = qr/($pos_re)\s+($no_re) ($name_re)($time_re)?/o;
my $even = qr/($no_re) ($name_re)($time_re)?\s+($pos_re)/o;
my ( $pos, $no, $name, $time, $entrant );

while (<GRID>) {
    if (   ( ( $pos, $no, $name, $time ) = /$odd/ )
        || ( ( $no, $name, $time, $pos ) = /$even/ ) )
    {
        ($entrant) = ( <GRID> =~ /^\s+($entrant_re)/o );
        $entrant =~ s/\s+$//;
        $name    =~ s/\s+$//;
        $time = 'no time ' unless defined $time;
        print "$pos\t$no\t$name\t$time\t$entrant\n";
    }
}

close GRID
    or die "bad PDFTOTEXT: $! $?";

