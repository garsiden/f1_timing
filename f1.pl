#! /usr/bin/env perl
use DBI;
use Data::Dumper;

use strict;
use warnings;
no strict 'vars';

# parse FIA F1 timing PDFs

$data_dir = "$ENV{HOME}/Documents/F1/aus/";

use constant PDFTOTEXT => '/usr/local/bin/pdftotext';

# shared regexs
$name_re       = q#[A-Z]\. [A-Z '-]+?#;
$driver_re     = $name_re;
$laptime_re    = '\d+:\d\d\.\d\d\d';
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
    #'aus-session1-classification' => \&first_practice_session_classification,

    # Qualifying
    #   'aus-qualifying-sectors' => \&qualifying_session_best_sector_times,
    #   'aus-qualifying-speeds' => \&qualifying_session_maximum_speeds,
    'aus-qualifying-times' => \&qualifying_session_lap_times,
    #   'aus-qualifying-trap' => \&qualifying_speed_trap,
    #
    # Race
    #   'aus-race-analysis' => \&race_lap_analysis,
    #   'aus-race-grid' => \&provisional_starting_grid,
    #   'aus-race-laps' => \&race_fastest_laps,
    #   'aus-race-sectors' => \&race_best_sector_times,
    #   'aus-race-speeds' => \&race_maximum_speeds,
    #   'aus-race-summary' => \&race_pit_stop_summary,
    #   'aus-race-trap' => \&race_speed_trap,

    # TODO
    #'aus-qualifying-classification' => \&qualifying_session_classification,
    #'aus-qualifying-times' => \&qualifying_session_lap_times,
    #
    #'aus-session1-times' => first_practice_session_lap_times,
    #'aus-session2-classification' => second_practice_session_classification,
    #'aus-session2-times' => second_practice_session_lap_times,
    #'aus-session2-classification' => third_practice_session_classification,
    #'aus-session3-times' => third_practice_session_lap_times,
    #
    # OTHERS
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
sub first_practice_session_classification
{
    my $text = shift;

    my $recs = practice_session_classification($text);

    print Dumper $recs;
    db_insert_array( 'aus-2011', 'practice_1_classification', $recs );
}

# QUALIFYING
sub qualifying_session_best_sector_times
{
    my $text = shift;

    my $table   = 'qualifying_best_sector_time';
    my $race_id = 'aus-2011';

    my $recs = best_sector_times($text);

    #print Dumper $recs;
    # add to database
    db_insert_array( $race_id, $table, $recs );
}

sub qualifying_session_maximum_speeds
{
    my $text = shift;

    my $table   = 'qualifying_maximum_speed';
    my $race_id = 'aus-2011';
    my $recs  = maximum_speeds($text);

    #print Dumper $recs;

    # add to database
    db_insert_array( $race_id, $table, $recs );
}

sub qualifying_session_lap_times
{
    my $text = shift;

    my $header_re  = qr/($no_re)\s+(?:$driver_re)/;
    my $laptime_re = qr/($lap_re)(?: *P)?\s+($timeofday_re|$laptime_re)\s?/;
    my ( @col_pos, $width, $prev_col, $len, $idx, $line, %recs );

  HEADER:
    while (<$text>) {
        if ( my @pos = /$header_re/g ) {

            # skip empty lines
            do { $line = <$text> } until $line !~ /^\n$/;

            # split page into two time columns per driver
            while ( $line =~ m/(NO +TIME\s+?){2}/g ) {
                push @col_pos, pos $line;
            }

          TIMES:
            while (<$text>) {
                redo HEADER if /$header_re/;
                next HEADER if /^\f/;
                next TIMES  if /^\n/;
                $len = length;
                $prev_col = $idx = 0;
                for my $col (@col_pos) {
                    $width = $col - $prev_col;
                    if ( $prev_col < $len ) {
                        if ( my %temp =
                            substr( $_, $prev_col, $width ) =~ /$laptime_re/g )
                        {
                            for my $k ( keys %temp ) {
                                $recs{ $pos[$idx] }{$k} = $temp{$k};
                            }
                        }
                        $prev_col = $col;
                        $idx++;
                    }
                }
            }
        }

    }

    #for my $k (sort keys %{$recs{'7'}}) {
    #    print $k, "\t", $recs{7}{$k}, "\n";
    #}
    #return;
    my @fields = qw( no lap time );
    db_insert_hash( 'aus-2011', 'qualifying_lap_time', \@fields, \%recs );
    #print Dumper %recs;
    for my $k ( sort { $a <=> $b } ( keys %{ $recs{4} } ) ) {
        print $k, "\t", $recs{4}{$k}, "\n";
    }
}

sub qualifying_speed_trap
{
    my $text = shift;

    my $recs = speed_trap($text);

    #print Dumper $speed;
    my $race_id = 'aus-2011';
    my $table   = 'qualifying_speed_trap';
    db_insert_array( $race_id, $table, $recs );
}

# RACE
sub race_lap_analysis
{
    my $text = shift;

    my $header_re  = qr/($pos_re)\s+(?:$driver_re)/;
    my $laptime_re = qr/($lap_re)(?: *P)?\s+($timeofday_re|$laptime_re)\s?/;
    my ( @col_pos, $width, $prev_col, $len, $idx, $line, %recs );

  HEADER:
    while (<$text>) {
        if ( my @pos = /$header_re/g ) {

            # skip empty lines
            while ($line = <$text>) { last if $line !~ /^\n$/; }

            # split page into two time columns per driver
            @col_pos = ();
            while ( $line =~ m/(LAP\s+TIME\s+?){2}/g ) {
                push @col_pos, pos $line;
            }

            #print Dumper @col_pos;
          TIMES:
            while (<$text>) {
                next TIMES  if (/^\n/);
                next HEADER if (/^\f/);
                $len = length;
                $prev_col = $idx = 0;
                for my $col (@col_pos) {
                    $width = $col - $prev_col;
                    if ( $prev_col < $len ) {
                        if ( my %temp =
                            substr( $_, $prev_col, $width ) =~ /$laptime_re/g )
                        {
                            for my $k ( keys %temp ) {
                                $recs{ $pos[$idx] }{$k} = $temp{$k};
                            }
                        }
                        $prev_col = $col;
                        $idx++;
                    }
                }
            }
        }

    }

    #for my $k (sort keys %{$recs{'7'}}) {
    #    print $k, "\t", $recs{7}{$k}, "\n";
    #}
    #return;
    my @fields = qw( no lap time );
    db_insert_hash( 'aus-2011', 'race_lap_analysis', \@fields, \%recs );
}

sub provisional_starting_grid
{
    my $text = shift;

    my $odd          = qr/($pos_re) +($no_re) +($driver_re)\s+($laptime_re)?/;
    my $even         = qr/($no_re) +($driver_re) +($laptime_re)? +($pos_re)/;
    my $entrant_line = qr/^ +($entrant_re)\s+/;
    my ( $pos, $no, $driver, $time, $entrant, @recs );

    while (<$text>) {
        if (   ( ( $pos, $no, $driver, $time ) = /$odd/ )
            || ( ( $no, $driver, $time, $pos ) = /$even/ ) )
        {
            ($entrant) = ( <$text> =~ /$entrant_line/ );
            $entrant =~ s/\s+$//;
            push @recs,
              {
                'pos',     $pos,     'no',   $no, 'driver', $driver,
                'entrant', $entrant, 'time', $time
              };
        }
    }

    #print Dumper \@recs;
    db_insert_array( 'aus-2011', 'race_grid', \@recs );
}

sub race_fastest_laps
{
    my $text = shift;

    my $on_re = $lap_re;
    my ( $pos, $no, $nat, $entrant, $laptime, $on, $gap, $kph, $timeofday );
    my $regex = qr/($pos_re) +($no_re) +($driver_re) +($nat_re) +($entrant_re)/;
    $regex .=
      qr/($laptime_re) +($on_re) +($gap_re)? +($kph_re) +($timeofday_re)/;
    my @recs;

    while (<$text>) {
        next unless /$regex/;
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
        push @recs,
          {
            'pos',     $pos,     'no',          $no,
            'driver',  $driver,  'nat',         $nat,
            'entrant', $entrant, 'time',        $time,
            'on_lap',  $on,      'gap',         $gap,
            'kph',     $kph,     'time_of_day', $timeofday,
          };
    }

    #print Dumper \@recs;
    db_insert_array( 'aus-2011', 'race_fastest_lap', \@recs );
}

sub race_best_sector_times
{
    my $text = shift;

    my $table   = 'race_best_sector_time';
    my $race_id = 'aus-2011';

    $recs = best_sector_times($text);

    # print Dumper $recs;
    # add to database
    db_insert_array( $race_id, $table, $recs );
}

sub race_pit_stop_summary
{
    my $text = shift;

    my ( $no, $driver, $entrant, $lap, $timeofday, $stop, $duration,
        $totaltime );
    my $stop_re      = '\d';
    my $duration_re  = '(?:\d+:)?\d\d\.\d\d\d';
    my $totaltime_re = $duration_re;
    my $regex = qr/($no_re) +($driver_re) {2,}($entrant_re?) +($lap_re) +/;
    $regex .= qr/($timeofday_re) +($stop_re) +($duration_re) +($totaltime_re)/;

    my @recs;

    while (<$text>) {
        next unless /$regex/;
        $no          = $1;
        $driver      = $2;
        $entrant     = $3;
        $lap         = $4;
        $time_of_day = $5;
        $stop        = $6;
        $duration    = $7;
        $totaltime   = $8;
        push @recs,
          {
            'no',          $no,          'driver',     $driver,
            'entrant',     $entrant,     'lap',        $lap,
            'time_of_day', $time_of_day, 'stop',       $stop,
            'duration',    $duration,    'total_time', $totaltime,
          };

    }

    #print Dumper \@recs;
    db_insert_array( 'aus-2011', 'race_pit_stop_summary', \@recs );
}

sub race_maximum_speeds
{
    my $text = shift;

    my $table   = 'race_maximum_speed';
    my $race_id = 'aus-2011';
    my $recs  = maximum_speeds($text);

    #print Dumper $speeds;

    # add to database
    db_insert_array( $race_id, $table, $recs );
}

sub race_speed_trap
{
    my $text = shift;

    my $recs = speed_trap($text);

    #print Dumper $recs;
    my $race_id = 'aus-2011';
    my $table   = 'race_speed_trap';
    db_insert_array( $race_id, $table, $recs );
}

# SHARED
sub practice_session_classification
{
    my $text = shift;

    my ( $pos, $no, $nat, $entrant, $laptime, $on, $gap, $kph, $timeofday );
    my $regex = qr/($pos_re) +($no_re) +($driver_re) +($nat_re) +($entrant_re)/;
    $regex .=
qr/($laptime_re)? *($lap_re) *($gap_re)? *($kph_re)? *($timeofday_re)?\s+/;
    my @recs;

    while (<$text>) {
        next unless /$regex/;
        $pos       = $1;
        $no        = $2;
        $driver    = $3;
        $nat       = $4;
        $entrant   = $5;
        $time      = $6;
        $laps      = $7;
        $gap       = $8;
        $kph       = $9;
        $timeofday = $10;
        $entrant =~ s/\s+$//;
        push @recs,
          {
            'pos',     $pos,     'no',          $no,
            'driver',  $driver,  'nat',         $nat,
            'entrant', $entrant, 'time',        $time,
            'laps',    $laps,    'gap',         $gap,
            'kph',     $kph,     'time_of_day', $timeofday,
          };
    }

    return \@recs;
}

sub speed_trap
{
    my $text = shift;

    my $regex =
      qr/^ +($pos_re) +($no_re) +($driver_re) +($kph_re) +($timeofday_re)\s+/;

    my @recs;

    while (<$text>) {
        next unless ( my ( $pos, $no, $driver, $kph, $timeofday ) = /$regex/ );
        push @recs,
          {
            'pos',         $pos,    'no',  $no,
            'driver',      $driver, 'kph', $kph,
            'time_of_day', $timeofday
          };
    }

    return \@recs;
}

sub maximum_speeds
{
    my $text = shift;

    my $regex  = qr/\G($driver_re) +($kph_re)\s+/;
    my $num_re = qr/ ($no_re) /;

    my ( $line, $driver, $time, $pos, $n, $speedtrap, @recs);

  LOOP: while ( $line = <$text> ) {
        pos $line = 0;
        next unless ( $line =~ /$num_re/g );
        $pos       = $1;
        $speedtrap = 0;
        while ( $line =~ /$num_re/g ) {
            $no = $1;
            next LOOP unless ( $driver, $kph ) = $line =~ /$regex/;
            push @recs,
              {
                'pos',       $pos,    'no',  $no,
                'driver',    $driver, 'kph', $kph,
                'speedtrap', ++$speedtrap
              };
        }
    }

    #print Dumper \@recs;
    return \@recs;
}

sub best_sector_times
{
    my $text = shift;

    my $regex  = qr/\G($driver_re) +($sectortime_re)\s+/;
    my $num_re = qr/ ($no_re) /;

    my ( $line, $driver, $time, $pos, $n, $sector, @recs );

  LOOP: while ( $line = <$text> ) {
        pos $line = 0;
        next unless ( $line =~ /$num_re/g );
        $pos    = $1;
        $sector = 0;
        while ( $line =~ /$num_re/g ) {
            $no = $1;
            next LOOP unless ( $driver, $time ) = $line =~ /$regex/;
            push @recs,
              {
                'pos',  $pos,  'no',     $no, 'driver', $driver,
                'time', $time, 'sector', ++$sector
              };
        }
    }

    #print Dumper \@recs;
    return \@recs;
}

# DATABASE
sub db_connect
{
    unless ($dbh and $dbh->ping) {
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
        my $stmt = sprintf "INSERT INTO %s (race_id, %s) VALUES (?, %s)",
          $table, join( ', ', @keys ), join( ', ', ('?') x scalar @keys );

        #print $stmt, "\n";
        my $sth = $dbh->prepare($stmt);

        # create an array for each field and fill from each record's hash value
        my @cols;

        for my $hash (@$array_ref) {
            foreach ( 0 .. $#keys ) {
                push @{ $cols[$_] }, $hash->{ $keys[$_] };
            }
        }

        #print Dumper @cols;
        # bind parameter arrays to prepared SQL statement
        $sth->bind_param_array( 1, $race_id );
        foreach ( 0 .. $#keys ) {
            $sth->bind_param_array( $_ + 2, \@{ $cols[$_] } );
        }

        $dbh->do("DELETE FROM $table WHERE race_id = ?", {}, $race_id);
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

# add hash to database where hash key is a field value, and value is a hash
# where key and value are both are fields values.
sub db_insert_hash
{
    my ( $race_id, $table, $keys, $hash_ref ) = @_;

    my $dbh = db_connect();
    my ( $tuples, @tuple_status );

    eval {

        # create insert sql statement with placeholders, using hash keys as
        # field names
        my $stmt = sprintf "INSERT INTO %s (race_id, %s) VALUES (?, %s)",
          $table, join( ', ', @$keys ), join( ', ', ('?') x scalar @$keys );
        
        #print $stmt, "\n";
        my $sth = $dbh->prepare($stmt);

        # create an array for each field and fill from each record's hash value
        my ( $idx, @cols );

        for my $k ( keys %$hash_ref ) {
            for my $k2 ( keys %{ $hash_ref->{$k} } ) {
                foreach ( 0 .. 2 ) {
                    push @{ $cols[$_] }, ( $k, $k2, $hash_ref->{$k}{$k2} )[$_];
                }
            }
        }

        #print Dumper @cols;
        # bind parameter arrays to prepared SQL statement
        $sth->bind_param_array( 1, $race_id );
        foreach ( 0 .. $#$keys ) {
            $sth->bind_param_array( $_ + 2, \@{ $cols[$_] } );
        }

        $dbh->do("DELETE FROM $table WHERE race_id = ?", undef, $race_id);
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
