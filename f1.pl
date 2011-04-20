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
$nat_re        = '[A-Z]{3}';
$on_re         = $lap_re;
$gap_re        = '\d{1,2}\.\d\d\d';
$kph_re        = '\d\d\d\.\d\d\d';

#$pwd = 'maggio26';
#$pwd =~ tr/a-mA-Mn-zN-Z/n-zN-Za-mA-M/;
#print $pwd, "/n/n";

# map PDFs to sub-routines
%pdf = (

    #'aus-race-grid' => \&provisional_starting_grid,
    #'aus-race-sectors' => \&race_best_sector_times,
    #'aus-race-speeds' => \&race_maximum_speeds,
    #'aus-race-analysis' => \&race_lap_analysis,
    'aus-race-laps' => \&race_fastest_laps,
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

sub race_fastest_laps
{
    my $text = shift;

    my ($pos, $no, $nat, $entrant, $laptime, $on, $gap, $kph, $timeofday);
    my $regex = qr/($pos_re)\s+($no_re)\s+($driver_re)($nat_re)($entrant_re)/;
    $regex .= qr/($laptime_re)\s+($on_re)\s+($gap_re)*\s+($kph_re)\s+($timeofday_re)/;
    my @laps;

    while (<$text>) {
        next unless /$regex/o ;
        $pos =$1;
        $no = $2;
        $driver = $3;
        $nat = $4;
        $entrant = $5;
        $laptime = $6;
        $on = $7;
        $gap = $8;
        $kph = $9;
        $timeofday = $10;
        $nat =~ s/\s+$//;
        $driver =~ s/\s+$//;
        $entrant =~ s/\s+$//;
        $entrant =~ s/^\s+//;
        push @laps, {
            'pos' , $pos,
            'no', $no,
            'driver', $driver,
            'nat', $nat,
            'entrant', $entrant,
            'laptime' ,$laptime,
            'on', $on,
            'gap', $gap,
            'kph', $kph,
            'timeofday', $timeofday,
        };
    }

    print Dumper @laps;
}

sub race_lap_analysis
{
    my $text = shift;

    my $header_re  = qr/($pos_re)\s+(?:$driver_re)/;
    my $laptime_re = qr/($lap_re)\sP?\s+($timeofday_re|$laptime_re)\s?/;
    my ( @col_pos, $width, $prev_col, $len, $idx, $line );
    my %laptime;

    HEADER: while (<$text>) {
        if ( my @pos = /$header_re/go ) {

            # skip empty lines
            while ( ( $line = <$text> ) =~ /^\s$/ ) { }

            # split page into two time columns per driver
            @col_pos = ();
            while ( $line =~ m/(LAP\s+TIME\s+){2}/g ) {
                push @col_pos, pos $line;
            }

            TIMES: while (<$text>) {
                next TIMES if (/^\n/);
                next HEADER if (/^\f/);
                $len = length;
                $prev_col = $idx = 0;
                for my $col (@col_pos) {
                    $width = $col - $prev_col - 1;
                    if ( $prev_col + $width <= $len ) {
                        if ( my %temp =
                            substr( $_, $prev_col, $width ) =~ /$laptime_re/go )
                        {
                            for my $k ( keys %temp ) {
                                $laptime{ $pos[$idx] }{ sprintf "%02d", $k } =
                                $temp{$k};
                            }
                        }
                        $prev_col = $col;
                        $idx++;
                    }
                }
            }
        }

    }
    foreach my $k ( sort keys %{ $laptime{24} } ) {
        print "$k\t$laptime{24}{$k}\n";
    }
}

sub race_maximum_speeds
{
    my $text = shift;

    my $regex = qr/($no_re) ($name_re)($maxspeed_re)/;

    while (<$text>) {
        if ( my @sector = /$regex/go ) {
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
        if ( my @sector = /$regex/go ) {
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

