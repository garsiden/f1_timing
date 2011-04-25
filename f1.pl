#! /usr/bin/env perl
use DBI;
use Data::Dumper;

use strict;
use warnings;
no strict 'vars';

# parse FIA F1 timing PDFs

$data_dir = "$ENV{HOME}/Documents/F1/";

use constant PDFTOTEXT => '/usr/local/bin/pdftotext';

# shared regexs
$name_re       = q#[A-Z]\. [A-Z '-]+?#;
$driver_re     = $name_re;
$laptime_re    = '\d:\d\d\.\d\d\d';
$sectortime_re = '\d\d\.\d\d\d';
$maxspeed_re   = '\d\d\d\.\d{1,3}';
$kph_re        = $maxspeed_re;
$entrant_re    = '[A-z &]+';
$pos_re        = '\d{1,2}';
$no_re         = $pos_re;
$lap_re        = '\d{1,2}';
$timeofday_re  = '\d\d:\d\d:\d\d';
$nat_re        = '[A-Z]{3}';
$gap_re        = '\d{1,2}\.\d\d\d';

# Database variables
$dbfile      = "$ENV{HOME}/Documents/F1/db/f1_timing.db3";
$data_source = "dbi:SQLite:dbname=$dbfile";
$pwd         = q{};
$user        = q{};
$dbh         = undef;

#$pwd = 'maggio26';
#$pwd =~ tr/a-mA-Mn-zN-Z/n-zN-Za-mA-M/;
#print $pwd, "/n/n";

# map PDFs to sub-routines
%pdf = (
    # Practice
    #
    # Qualifying
    # 'aus-qualifying-sectors' => \&qualifying_session_best_sector_times,
    #
    # Race
    'aus-race-grid' => \&provisional_starting_grid,
    #'aus-race-sectors' => \&race_best_sector_times,
    #'aus-race-speeds' => \&race_maximum_speeds,
    #'aus-race-analysis' => \&race_lap_analysis,
    #'aus-race-laps' => \&race_fastest_laps,
    #'aus-race-summary' => \&race_pit_stop_summary,
    #'aus-race-trap' => \&race_speed_trap,
    # TODO
    #'aus-qualifying-speeds' => \&qualifying_session_maximum_speeds,
    #'aus-qualifying-times' => \&qualifying_session_lap_times,
    #'aus-session1-classification' => first_practice_session_classification,
    #'aus-session1-times' => first_practice_session_lap_times,
    #'aus-session2-classification' => second_practice_session_classification,
    #'aus-session2-times' => second_practice_session_lap_times,
    #'aus-session3-classification' => third_practice_session_classification,
    #'aus-session3-times' => third_practice_session_lap_times,
    #
    # OTHERS
    # 'aus-qualifying-classification,
    # 'aus-race-chart'
    # 'aus-race-classification'
    # 'aus-race-history'
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

sub race_speed_trap
{
    my $text = shift;

    #my $kph_re = '\d\d\d\.\d';
    my $regex =
      qr/($pos_re)\s+($no_re)\s+($driver_re)\s+($kph_re)\s+($timeofday_re)/;

    my @speed;

    while (<$text>) {
        next unless ( my ( $pos, $no, $driver, $kph, $timeofday ) = /$regex/ );
        push @speed,
          {
            'pos',       $pos,    'no',  $no,
            'driver',    $driver, 'kph', $kph,
            'timeofday', $timeofday
          };
    }

    print Dumper @speed;
}

sub race_pit_stop_summary
{
    my $text = shift;

    my ( $no, $driver, $entrant, $lap, $timeofday, $stop, $duration,
        $totaltime );
    my $stop_re      = '\d';
    my $duration_re  = '(?:\d+:)?\d\d\.\d\d\d';
    my $totaltime_re = $duration_re;
    my $regex = qr/($no_re)\s+($driver_re)\s+($entrant_re)\s+($lap_re)\s+/;
    $regex .=
      qr/($timeofday_re)\s+($stop_re)\s+($duration_re)\s+($totaltime_re)/;

    my @pitsops;
    print $regex;

    while (<$text>) {
        next unless /$regex/o;
        $no        = $1;
        $driver    = $2;
        $entrant   = $3;
        $lap       = $4;
        $timeofday = $5;
        $stop      = $6;
        $duration  = $7;
        $totaltime = $8;

        push @pitstops,
          {
            'no',        $no,        'driver',    $driver,
            'entrant',   $entrant,   'lap',       $lap,
            'time_of_day', $timeofday, 'stop',      $stop,
            'duration',  $duration,  'total_time', $totaltime,
          };

    }
    print Dumper @pitstops;
}

sub race_fastest_laps
{
    my $text = shift;

    my $on_re = $lap_re;
    my ( $pos, $no, $nat, $entrant, $laptime, $on, $gap, $kph, $timeofday );
    my $regex = qr/($pos_re)\s+($no_re)\s+($driver_re)($nat_re)($entrant_re)/;
    $regex .=
      qr/($laptime_re)\s+($on_re)\s+($gap_re)*\s+($kph_re)\s+($timeofday_re)/;
    my @laps;

    while (<$text>) {
        next unless /$regex/o;
        $pos       = $1;
        $no        = $2;
        $driver    = $3;
        $nat       = $4;
        $entrant   = $5;
        $laptime   = $6;
        $on        = $7;
        $gap       = $8;
        $kph       = $9;
        $timeofday = $10;
        $nat     =~ s/\s+$//;
        $driver  =~ s/\s+$//;
        $entrant =~ s/\s+$//;
        $entrant =~ s/^\s+//;
        push @laps,
          {
            'pos',     $pos,     'no',        $no,
            'driver',  $driver,  'nat',       $nat,
            'entrant', $entrant, 'laptime',   $laptime,
            'on',      $on,      'gap',       $gap,
            'kph',     $kph,     'timeofday', $timeofday,
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
                next TIMES  if (/^\n/);
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

sub qualifying_session_best_sector_times
{
    my $text = shift;

    my $regex  = qr/\G($driver_re) +($sectortime_re)\s+/;
    my $num_re = qr/ ($no_re) /;

    my @times;
    my ( $line, $driver, $time, $pos, $n, $sector );

  LOOP: while ( $line = <$text> ) {
        pos $line = 0;
        next unless ( $line =~ /$num_re/g );
        $pos    = $1;
        $sector = 0;
        while ( $line =~ /$num_re/g ) {
            $no = $1;
            next LOOP unless ( $driver, $time ) = $line =~ /$regex/;
            push @times,
              {
                'pos',  $pos,  'no',     $no, 'driver', $driver,
                'time', $time, 'sector', ++$sector
              };
        }
    }

    #print Dumper @times;

    # add to database
    my $table   = 'qualifying_sector';
    my $race_id = 'aus-2011';
    db_insert_array( $race_id, $table, \@times );
}

sub race_best_sector_times
{
    my $text = shift;

    my $regex = qr/($no_re) ($driver_re)($sectortime_re)/;

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

    my $odd  = qr/($pos_re) +($no_re) +($driver_re)\s+($laptime_re)?/o;
    my $even = qr/($no_re) +($driver_re) +($laptime_re)? +($pos_re)/o;
    my $entrant_line = qr/^ +($entrant_re)\s+/o;
    my ( $pos, $no, $driver, $time, $entrant, @grid );

    while (<$text>) {
        if (   ( ( $pos, $no, $driver, $time ) = /$odd/ )
            || ( ( $no, $driver, $time, $pos ) = /$even/ ) )
        {
            ($entrant) = ( <$text> =~ /$entrant_line/ );
            $entrant =~ s/\s+$//;
            push @grid,
              {
                'pos',     $pos,     'no',   $no, 'driver', $driver,
                'entrant', $entrant, 'time', $time
              };
        }
    }

    db_insert_array( 'aus-2011', 'race_grid', \@grid );
}

sub db_connect
{
    unless ($dbh) {
        $dbh = DBI->connect( $data_source, $user, $pwd )
          or die $DBI::errstr;
        $dbh->{AutoCommit} = 0;
        $dbh->{RaiseError} = 1;
    }

    return $dbh;
}

sub db_insert_array
{
    my ( $race_id, $table, $array_ref ) = @_;

    my $dbh = db_connect();

    eval {
        my @keys = keys %{ $$array_ref[0] };
        # create insert sql statement with placeholders, using hash keys as
        # field names
        my $stmt = "INSERT INTO $table (race_id, " . join ', ', @keys;
        $stmt .= ") VALUES(?, " . join ', ', ('?') x scalar @keys;
        $stmt .= ")";
    
        print $stmt, "\n";
        my $sth = $dbh->prepare($stmt);

        # create an array for each field and fill from each records hash value
        my @cols;

        for my $t (@$array_ref) {
            for my $c ( 0 .. $#keys ) {
                push @{ $cols[$c] }, $t->{ $keys[$c] };
            }
        }
        print Dumper @cols;
        # bind parameter arrays to prepared SQL statement
        $sth->bind_param_array( 1, $race_id );
        for my $c ( 0 .. $#keys ) {
            $sth->bind_param_array( $c + 2, \@{ $cols[$c] } );
        }

        $sth->execute_array( { ArrayTupleStatus => \my @tuple_status } );
        $dbh->commit;
    };
    if ($@) {
        warn "Transaction aborted because: $@";
        eval { $dbh->rollback };
    }
}
