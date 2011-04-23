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
$entrant_re    = '[A-z &]+?';
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

    #'aus-race-grid' => \&provisional_starting_grid,
    #'aus-race-sectors' => \&race_best_sector_times,
    #'aus-race-speeds' => \&race_maximum_speeds,
    #'aus-race-analysis' => \&race_lap_analysis,
    #'aus-race-laps' => \&race_fastest_laps,
    #'aus-race-summary' => \&race_pit_stop_summary,
    #'aus-race-trap' => \&race_speed_trap,
    'aus-qualifying-sectors' => \&qualifying_best_sector_times,
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
            'timeofday', $timeofday, 'stop',      $stop,
            'duration',  $duration,  'totaltime', $totaltime,
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

sub qualifying_best_sector_times
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
    print Dumper @times;

    # add to database
    my $dbh = db_connect();
    my $stmt =
        'INSERT INTO qualifying_sector (race_id,pos,no,driver,sector,time)'
      . 'VALUES(?,?,?,?,?,?)';
    my $sth = $dbh->prepare($stmt);

    my ( @pos_vals, @no_vals, @driver_vals, @sector_vals, @time_vals );
    for my $t (@times) {
        push @pos_vals,    $t->{pos};
        push @no_vals,     $t->{no};
        push @driver_vals, $t->{driver};
        push @sector_vals, $t->{sector};
        push @time_vals,   $t->{time};
    }

    print Dumper @pos_vals;
    $sth->bind_param_array( 1, 'aus-2011' );
    $sth->bind_param_array( 2, \@pos_vals );
    $sth->bind_param_array( 3, \@no_vals );
    $sth->bind_param_array( 4, \@driver_vals );
    $sth->bind_param_array( 5, \@sector_vals );
    $sth->bind_param_array( 6, \@time_vals );

    $sth->execute_array( { ArrayTupleStatus => \my @tuple_status } );
    $dbh->commit;

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

sub add_db_list
{
    my $dbh = db_connect();

    # Add to submissions lists  (for testing delete from table first)
    # $dbh->do("DELETE FROM webs_core;");

    # prepare statements to add to webs_core and webs_obs tables
    my ( @keys, $statement, $sth_sub, $sth_obs );
    @keys = qw! sub_id core_date start_time end_time note !;
    $statement =
      "INSERT INTO webs_core (" . join( ", ", @keys ) . ") VALUES(?,?,?,?,?);";
    $sth_sub = $dbh->prepare($statement);

    $sth_obs = $dbh->prepare(
        "INSERT INTO webs_obs (sub_id, bto_code, count) VALUES(?,?,?)");

    # ensure BTO codes are available
    #my $bto_href = get_bto_codes();

    # loop through array of subs list and add to webs_core & webs_obs
    my ( $sub_id, @obs, @values, @count_values, @bto_values );

    for my $sref (@_) {
        eval {
            @values = @count_values = @bto_values = ();
            $sub_id = $sref->{sub_id};

            # add submissions list
            for my $key (@keys) { push @values, $sref->{$key}; }
            $sth_sub->execute(@values);

            # add observations into webs_obs
            @obs = @{ $sref->{obs} };
            for my $oref (@obs) {

                #$bto = $bto_href->{ $oref->{species} }
                #or die "No BTO code for $oref->{species} in list $sub_id\n";
                #push @bto_values,   $bto;
                push @count_values, $oref->{count};
            }
            $sth_obs->bind_param_array( 1, $sub_id );
            $sth_obs->bind_param_array( 2, \@bto_values );
            $sth_obs->bind_param_array( 3, \@count_values );
            $sth_obs->execute_array(
                { ArrayTupleStatus => \my @tuple_status } );
            $dbh->commit;
        };
        if ($@) {
            warn "Transaction aborted because: $@";
            eval { $dbh->rollback };
        }
    }
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

