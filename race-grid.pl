#! /usr/bin/env perl

#use strict;
use warnings;

# parse race grid from text file

my $data_dir = 'data/src/';
my $grid_txt = 'aus-race-grid.txt';
my $path     = $data_dir . $grid_txt;
my $grid_pdf = "$ENV{HOME}/Documents/F1/aus-race-grid.pdf";
use constant PDFTOTEXT => '/usr/local/bin/pdftotext';

$name_re    = q#[A-Z]\. [A-Z '-]+#;
$time_re    = '\d:\d\d\.\d\d\d';
$entrant_re = '[\w &]+';
$pos_re     = '\d{1,2}';
$no_re      = $pos_re;

#open my $grid, "<", $path
#  or die "Unable to open file $path: $!\n";
# use to arg open method to get shell redirection to stdout

open $grid, "PDFTOTEXT -layout $grid_pdf - |"
      or die "unable to open PDFTOTEXT: $!";

race_grid($grid);

sub race_grid
{
    my $text = shift;

    while (<$text>) {

        my $odd  = qr/($pos_re)\s+($no_re) ($name_re)($time_re)?/o;
        my $even = qr/($no_re) ($name_re)($time_re)?\s+($pos_re)/o;
        my ( $pos, $no, $name, $time, $entrant );

        if (   ( ( $pos, $no, $name, $time ) = /$odd/ )
            || ( ( $no, $name, $time, $pos ) = /$even/ ) )
        {
            ($entrant) = ( <$text> =~ /^\s+($entrant_re)/o );
            $entrant =~ s/\s+$//;
            $name    =~ s/\s+$//;
            $time = 'no time ' unless defined $time;
            print "$pos\t$no\t$name\t$time\t$entrant\n";
        }
    }

    close $text
      or die "bad PDFTOTEXT: $! $?";
}

