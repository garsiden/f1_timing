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
$entrant_re    = '[A-z0-9& -]+';
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
    #'aus-qualifying-sectors' => \&qualifying_session_best_sector_times,
    #'aus-qualifying-speeds' => \&qualifying_session_maximum_speeds,
    #'aus-qualifying-trap' => \&qualifying_speed_trap,
    #
    # Race
    'aus-race-analysis' => \&race_lap_analysis,
    #'aus-race-grid' => \&provisional_starting_grid,
    #'aus-race-trap' => \&race_speed_trap,
    #'aus-race-sectors' => \&race_best_sector_times,
    #'aus-race-speeds' => \&race_maximum_speeds,

    #'aus-race-laps' => \&race_fastest_laps,
    #'aus-race-summary' => \&race_pit_stop_summary,
    # TODO
    #'aus-qualifying-classification' => \&qualifying_session_classification,
    #'aus-qualifying-times' => \&qualifying_session_lap_times,
    #
    #'aus-session1-classification' => first_practice_session_classification,
    #'aus-session1-times' => first_practice_session_lap_times,
    #'aus-session2-classification' => second_practice_session_classification,
    #'aus-session2-times' => second_practice_session_lap_times,
    #'aus-session2-classification' => third_practice_session_classification,
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
# PRACTICE


# QUALIFYING
sub qualifying_session_best_sector_times
{
    my $text = shift;

    my $table   = 'qualifying_best_sector_time';
    my $race_id = 'aus-2011';

    $times = best_sector_times($text);

    #print Dumper $times;
    # add to database
    db_insert_array( $race_id, $table, $times );
}

sub qualifying_session_maximum_speeds
{
    my $text = shift;

    my $table   = 'qualifying_maximum_speed';
    my $race_id = 'aus-2011';
    my $speeds  = maximum_speeds($text);

    print Dumper $speeds;

    # add to database
    db_insert_array( $race_id, $table, $speeds );
}

sub qualifying_speed_trap
{
    my $text = shift;

    my $speed = speed_trap($text);

    print Dumper $speed;
    my $race_id = 'aus-2011';
    my $table = 'qualifying_speed_trap';
    db_insert_array($race_id, $table, $speed);
}

# RACE
sub race_lap_analysis
{
    my $text = shift;

    my $header_re  = qr/($pos_re) +(?:$driver_re)/;
    my $laptime_re = qr/($lap_re) (?:P)? +($timeofday_re|$laptime_re)\s?/;
    my ( @col_pos, $width, $prev_col, $len, $idx, $line );
    my %laptime;

  HEADER: while (<$text>) {
        if ( my @pos = /$header_re/g ) {

            # skip empty lines
            while ( ( $line = <$text> ) =~ /^\s$/ ) { }

            # split page into two time columns per driver
            @col_pos = ();
            while ( $line =~ m/(LAP +TIME\s+){2}/g ) {
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
                            substr( $_, $prev_col, $width ) =~ /$laptime_re/g )
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
    #foreach my $k ( sort keys %{ $laptime{24} } ) {
    #    print "$k\t$laptime{24}{$k}\n";
    #}
    print Dumper %laptime;
}
sub provisional_starting_grid
{
    my $text = shift;

    my $odd          = qr/($pos_re) +($no_re) +($driver_re)\s+($laptime_re)?/;
    my $even         = qr/($no_re) +($driver_re) +($laptime_re)? +($pos_re)/;
    my $entrant_line = qr/^ +($entrant_re)\s+/;
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

    print Dumper @grid;
    db_insert_array( 'aus-2011', 'race_grid', \@grid );
}

sub race_speed_trap
{
    my $text = shift;

    my $speed = speed_trap($text);

    print Dumper $speed;
    my $race_id = 'aus-2011';
    my $table = 'race_speed_trap';
    db_insert_array($race_id, $table, $speed);
}

sub race_best_sector_times
{
    my $text = shift;

    my $table   = 'race_best_sector_time';
    my $race_id = 'aus-2011';

    $times = best_sector_times($text);

    # print Dumper $times;
    # add to database
    db_insert_array( $race_id, $table, $times );
}

sub race_maximum_speeds
{
    my $text = shift;

    my $table   = 'race_maximum_speed';
    my $race_id = 'aus-2011';
    my $speeds  = maximum_speeds($text);

    print Dumper $speeds;

    # add to database
    db_insert_array( $race_id, $table, $speeds );
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
        $no          = $1;
        $driver      = $2;
        $entrant     = $3;
        $lap         = $4;
        $time_of_day = $5;
        $stop        = $6;
        $duration    = $7;
        $totaltime   = $8;

        push @pitstops,
          {
            'no',          $no,          'driver',     $driver,
            'entrant',     $entrant,     'lap',        $lap,
            'time_of_day', $time_of_day, 'stop',       $stop,
            'duration',    $duration,    'total_time', $totaltime,
          };

    }
    print Dumper @pitstops;
}

sub race_fastest_laps
{
    my $text = shift;

    my $on_re = $lap_re;
    my ( $pos, $no, $nat, $entrant, $laptime, $on, $gap, $kph, $timeofday );
    my $regex = qr/($pos_re) +($no_re) +($driver_re) +($nat_re) +($entrant_re)/;
    $regex .=
      qr/($laptime_re) +($on_re) +($gap_re)? +($kph_re) +($timeofday_re)/;
    my @laps;

    while (<$text>) {
        next unless /$regex/o;
        $pos       = $1;
        $no        = $2;
        $driver    = $3;
        $nat       = $4;
        $entrant   = $5;
        $time      = $6;
        $on        = $7;
        $gap       = $8;
        $kph       = $9;
        $timeofday = $10;
        $entrant =~ s/\s+$//;
        push @laps,
          {
            'pos',     $pos,     'no',          $no,
            'driver',  $driver,  'nat',         $nat,
            'entrant', $entrant, 'time',        $time,
            'on_lap',  $on,      'gap',         $gap,
            'kph',     $kph,     'time_of_day', $timeofday,
          };
    }

    print Dumper @laps;
    db_insert_array( 'aus-2011', 'race_fastest_lap', \@laps );
}



# SHARED
sub speed_trap
{
    my $text = shift;

    my $regex =
      qr/^ +($pos_re) +($no_re) +($driver_re) +($kph_re) +($timeofday_re)\s+/;

    my @speed;

    while (<$text>) {
        next unless ( my ( $pos, $no, $driver, $kph, $timeofday ) = /$regex/ );
        push @speed,
          {
            'pos',         $pos,    'no',  $no,
            'driver',      $driver, 'kph', $kph,
            'time_of_day', $timeofday
          };
    }

    return \@speed;
}

sub maximum_speeds
{
    my $text = shift;

    my $regex  = qr/\G($driver_re) +($kph_re)\s+/;
    my $num_re = qr/ ($no_re) /;

    my @speeds;
    my ( $line, $driver, $time, $pos, $n, $speedtrap );

  LOOP: while ( $line = <$text> ) {
        pos $line = 0;
        next unless ( $line =~ /$num_re/g );
        $pos       = $1;
        $speedtrap = 0;
        while ( $line =~ /$num_re/g ) {
            $no = $1;
            next LOOP unless ( $driver, $kph ) = $line =~ /$regex/;
            push @speeds,
              {
                'pos',       $pos,    'no',  $no,
                'driver',    $driver, 'kph', $kph,
                'speedtrap', ++$speedtrap
              };
        }
    }

    #print Dumper @times;
    return \@speeds;
}

sub best_sector_times
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
    return \@times;
}


# DATABASE
sub db_connect
{
    unless ($dbh) {
        $dbh = DBI->connect( $data_source, $user, $pwd )
          or die $DBI::errstr;
        $dbh->{AutoCommit} = 0;
        $dbh->{RaiseError} = 1;
        $dbh->do("PRAGMA foreign_keys = ON");
    }

    return $dbh;
}

sub db_insert_array
{
    my ( $race_id, $table, $array_ref ) = @_;

    my $dbh = db_connect();
    my $tuples;
    my @tuple_status;

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

        for my $hash (@$array_ref) {
            map { push @{ $cols[$_] }, $hash->{ $keys[$_] } } ( 0 .. $#keys )
        }

        #print Dumper @cols;
        # bind parameter arrays to prepared SQL statement
        $sth->bind_param_array( 1, $race_id );
        for my $c ( 0 .. $#keys ) {
            $sth->bind_param_array( $c + 2, \@{ $cols[$c] } );
        }

        $tuples = $sth->execute_array( { ArrayTupleStatus => \@tuple_status } );
        $dbh->commit;
    };
    if ($@) {
        print Dumper @tuple_status;
        warn "Transaction aborted because: $@";
        eval { $dbh->rollback };
    }
    else {
        print "$tuples record(s) added to table $table\n";
    }

    return $tuples;
}
