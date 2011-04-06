#! /usr/bin/env perl
use Data::Dumper;

use strict;
use warnings;
no strict 'vars';

# parse FIA F1 timing PDFs

$data_dir = "$ENV{HOME}/Documents/F1/";

use constant PDFTOTEXT => '/usr/local/bin/pdftotext';

# shared regexs
$name_re       = q#[A-Z]\. [A-Z '-]+#;
$laptime_re    = '\d:\d\d\.\d\d\d';
$sectortime_re = '\d\d\.\d\d\d';
$maxspeed_re   = '\d\d\d\.\d';
$entrant_re    = '[\w &]+';
$pos_re        = '\d{1,2}';
$no_re         = $pos_re;
$driver_re     = $name_re;
$lap_re        = '\d{1,2}';
$timeofday_re  = '\d\d:\d\d:\d\d';

# map PDFs to sub-routines
%pdf = (

    #'aus-race-grid' => \&provisional_starting_grid,
    #'aus-race-sectors' => \&race_best_sector_times,
    #'aus-race-speeds' => \&race_maximum_speeds,
    'aus-race-analysis' => \&race_lap_analysis,
);

for my $key ( keys %pdf ) {
    my $pdf = $data_dir . $key;

    # use to arg open method to get shell redirection to stdout
    open my $text, "PDFTOTEXT -layout $pdf.pdf - |"
        or die "unable to open PDFTOTEXT: $!";
    $pdf{$key}($text);

    close $text
        or die "bad PDFTOTEXT: $! $?";
}

sub race_lap_analysis
{
    my $text = shift;

    my $header_re = qr/($pos_re)\s+($driver_re)/;
    my $laptest_re    = qr/($lap_re)\sP?\s+($timeofday_re|$laptime_re)\s?/;
    my $laps_re   = qr/$lap_re$lap_re$lap_re/;
    my $test_re    = qr/($laptime_re|$timeofday_re)/;
    my($no, $time);

    my ($c1, $c2, $c3, $c4, $c5, $c6);
    HEADER: while (<$text>) {
        if ( my %driver = /$header_re/go ) {
            for my $k (sort keys %driver) {
                $driver{$k} =~ s/\s+$//;
                print "$k\t$driver{$k}\n";
            }
            for ($i = 0; $i < 4; $i++) { readline $text }
            while (<$text>) {
                if ( length == 1) { next HEADER }
                while (/(\d{1,2})\s+(\d\d:\d\d:\d\d|\d:\d\d\.\d\d\d)/g) {
                    $no = $1;
                    $time = $2;
                    #my $n = scalar @lt;
                    #print Dumper @lt;
                    printf "%d\t%s\t%s\t",  pos, $no, $time;
                }
                print "\n========\n";
            }
        }
    }

}

sub race_maximum_speeds
{
    my $text = shift;

    my $regex = qr/($no_re) ($name_re)($maxspeed_re)/;

    while (<$text>) {
        if ( my @sector  = /$regex/go ) {
            foreach (@sector) { s/\s+$// }
            print "$sector[0]\t$sector[1]\t$sector[2]\t";
            print "$sector[3]\t$sector[4]\t$sector[5]\t";
            print "$sector[6]\t$sector[7]\t$sector[8]\n";
        }
    }
}
sub race_best_sector_times
{
    my $text = shift;

    my $regex = qr/($no_re) ($name_re)($sectortime_re)/;

    while (<$text>) {
        if ( my @sector  = /$regex/go ) {
            foreach (@sector) { s/\s+$// }
            print "$sector[0]\t$sector[1]\t$sector[2]\t";
            print "$sector[3]\t$sector[4]\t$sector[5]\t";
            print "$sector[6]\t$sector[7]\t$sector[8]\n";
        }
    }
}

sub provisional_starting_grid
{
    my $text = shift;

    while (<$text>) {

        my $odd  = qr/($pos_re)\s+($no_re) ($name_re)($laptime_re)?/o;
        my $even = qr/($no_re) ($name_re)($laptime_re)?\s+($pos_re)/o;
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
}

