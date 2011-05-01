#! /usr/bin/env perl
use DBI;
use Data::Dumper;

use strict;
use warnings;
no strict 'vars';

# parse FIA F1 timing PDFs

$data_dir = "$ENV{HOME}/Documents/F1/aus/";
$race_id  = 'aus-2011';
$quiet    = 1;

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
    'aus-session1-classification' => {
        parser => \&practice_session_classification,
        table  => 'practice_1_classification',
    },

    # Qualifying
    'aus-qualifying-sectors' => {
        parser => \&best_sector_times,
        table  => 'qualifying_best_sector_time',
    },
    'aus-qualifying-speeds' => {
        parser => \&maximum_speeds,
        table  => 'qualifying_maximum_speed',
    },
    'aus-qualifying-times' => {
        parser => \&time_sheet,
        table  => 'qualifying_lap_time',
    },
    'aus-qualifying-trap' => {
        parser => \&speed_trap,
        table  => 'qualifying_speed_trap',
    },

    # Race
    'aus-race-analysis' => {
        parser => \&time_sheet,
        table  => 'race_lap_analysis',
    },
    'aus-race-grid' => {
        parser => \&provisional_starting_grid,
        table  => 'race_grid',
    },
    'aus-race-laps' => {
        parser => \&race_fastest_laps,
        table  => 'race_fastest_lap',
    },
    'aus-race-sectors' => {
        parser => \&best_sector_times,
        table  => 'race_best_sector_time',
    },
    'aus-race-speeds' => {
        parser => \&maximum_speeds,
        table  => 'race_maximum_speed',
    },
    'aus-race-summary' => {
        parser => \&race_pit_stop_summary,
        table  => 'race_pit_stop_summary',
    },
    'aus-race-trap' => {
        parser => \&speed_trap,
        table  => 'race_speed_trap',
    },

    # TODO
    #'aus-qualifying-classification' => \&qualifying_session_classification,
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
    #my $key = 'aus-qualifying-times';
    my $pdf = $data_dir . $key;
    # use to arg open method to get shell redirection to stdout
    open my $text, "PDFTOTEXT -layout $pdf.pdf - |"
      or die "unable to open PDFTOTEXT: $!";
    $href = $pdf{$key};
    $recs = $href->{parser}($text);
    print Dumper $recs unless $quiet;
    $table = $href->{table};

    db_insert_array( $race_id, $table, $recs );
    close $text
      or die "bad PDFTOTEXT: $! $?";
}

# PRACTICE

# QUALIFYING

# RACE
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

    return \@recs;
}

sub race_fastest_laps
{
    my @fields = qw( pos no driver nat entrant time on_lap gap kph time_of_day );
    my $aref = classification( @_, @fields );

    return $aref;
}

sub race_pit_stop_summary
{
    my $text = shift;

    my @fields = qw( no driver entrant lap time_of_day stop duration total_time );
    my $stop_re      = '\d';
    my $duration_re  = '(?:\d+:)?\d\d\.\d\d\d';
    my $totaltime_re = $duration_re;
    my $regex = qr/($no_re) +($driver_re) {2,}($entrant_re?) +($lap_re) +/;
    $regex .= qr/($timeofday_re) +($stop_re) +($duration_re) +($totaltime_re)/;

    my @recs;

    while (<$text>) {
        my %hash;
        next unless (@hash{ @fields} = /$regex/);
        push @recs, \%hash;
    }

    return \@recs;
}

# SHARED
#
# 3 sets of times across a page in two columns per driver
# used by race lap analysis and qualifying lap times
sub time_sheet
{
    my $text = shift;

    my $header_re  = qr/($no_re)\s+(?:$driver_re)/;
    my $laptime_re = qr/($lap_re) *(P)? +($timeofday_re|$laptime_re)\s?/;
    my ( @col_pos, $width, $prev_col, $len, $idx, $line, @recs );
    my @fields = qw(no lap pit time);

  HEADER:
    while (<$text>) {
        if ( my @pos = /$header_re/g ) {

            # skip empty lines
            do { $line = <$text> } until $line !~ /^\n$/;

            # split page into two time columns per driver
            while ( $line =~ m/((?:NO|LAP) +TIME\s+?){2}/g ) {
                push @col_pos, pos $line;
            }

          TIMES:
            while (<$text>) {
                next HEADER if /^\f/;
                redo HEADER if /$header_re/;
                next TIMES  if /^\n/;
                $len = length;
                $prev_col = $idx = 0;
                for my $col (@col_pos) {
                    $width = $col - $prev_col;
                    if ( $prev_col < $len ) {
                        while (
                            substr( $_, $prev_col, $width ) =~ /$laptime_re/g )
                        {
                            my %temp;
                            @temp{ @fields } = ( $pos[$idx], $1, $2, $3 );
                            push @recs, \%temp;
                        }
                        $prev_col = $col;
                        $idx++;
                    }
                }
            }
        }
    }

    return \@recs;
}

# used by race fastest laps and practice session classification
sub classification
{
    my $text   = shift;
    my @fields = @_;

    my $regex =
      qr/($pos_re) +($no_re) +($driver_re) +($nat_re) +($entrant_re?) +/;
    $regex .=
qr/($laptime_re)? *($lap_re) *($gap_re)? *($kph_re)? *($timeofday_re)?\s+/;
    my @recs;

    while (<$text>) {
        my %hash;
        next unless ( @hash{@fields} = /$regex/ );
        push @recs, \%hash;
    }

    return \@recs;
}

sub practice_session_classification
{
    my @fields = qw( pos no driver nat entrant time laps gap kph time_of_day);
    my $recs = classification( @_, @fields );

    return $recs;
}

sub speed_trap
{
    my $text = shift;

    my $regex =
      qr/^ +($pos_re) +($no_re) +($driver_re) +($kph_re) +($timeofday_re)\s+/;

    my @recs;
    my @fields = qw( pos no driver kph time_of_day);

    while (<$text>) {
        my %hash;
        next unless ( @hash{@fields} = /$regex/ );
        push @recs, \%hash;
    }

    return \@recs;
}

sub maximum_speeds
{
    my $text = shift;

    my $regex  = qr/\G($driver_re) +($kph_re)\s+/;
    my $num_re = qr/ ($no_re) /;

    my ( $line, $driver, $time, $pos, $n, $speedtrap, @recs );

  LOOP:
    while ( $line = <$text> ) {
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

    return \@recs;
}

sub best_sector_times
{
    my $text = shift;

    my $regex  = qr/\G($driver_re) +($sectortime_re)\s+/;
    my $num_re = qr/ ($no_re) /;

    my ( $line, $driver, $time, $pos, $n, $sector, @recs );

  LOOP:
    while ( $line = <$text> ) {
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

    return \@recs;
}

# DATABASE
sub db_connect
{
    unless ( $dbh and $dbh->ping ) {
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

        my $tuple_fetch = sub {
            my $href = pop @{$array_ref};
            return unless defined $href;
            [ $race_id, @$href{@keys} ];
        };

        $dbh->do( "DELETE FROM $table WHERE race_id = ?", {}, $race_id );
        $tuples = $sth->execute_array(
            {
                ArrayTupleStatus => \@tuple_status,
                ArrayTupleFetch  => $tuple_fetch,
            }
        );
        $dbh->commit;
    };
    if ($@) {
        print "Table: $table\n";
        print Dumper @tuple_status;
        warn "Transaction aborted because: $@";
        eval { $dbh->rollback };
    }
    else {
        print "$tuples record(s) added to table $table\n";
    }

    return $tuples;
}
