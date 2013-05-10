#! /usr/bin/env perl

use DBI;
use Data::Dumper;
use Chart::Gnuplot;

use strict;
use warnings;
use 5.012;

# config constants
use constant SEASON   => '2013';
use constant DOCS_DIR => "$ENV{HOME}/Documents/F1/";

# database constants
use constant DB_PATH => "$ENV{HOME}/Documents/F1/" . SEASON
  . '/db/f1_timing.db';
use constant DB_PWD  => q{};
use constant DB_USER => q{};

# graph global variables
my $font = 'Monaco';
my $graph_font = "$font, 12";
my $legend_font = "$font, 10";
my $dashed  = 'dashed';       # solid|dashed

my $db_path = undef;

# database session handle
my $db_session = db_connect();

my %colours = (
    1,  "#020138", 2,  "#485184", 3,  "#B80606", 4,  "#B80606", 5,  "#B7BACC",
    6,  "#D0D7DF", 7,  "#F8A62D", 8,  "#F9D61A", 9,  "#72A5A6", 10, "#A7C8C9",
    11, "#646564", 12, "#989898", 14, "#B2C61B", 15, "#D6E741", 16, "#3F62A6",
    17, "#6E94C0", 18, "#640F6F", 19, "#A36FAA", 20, "#076214", 21, "#7EAE7B",
    22, "#ED528A", 23, "#F5AAC4",
);

use constant RACE_ID => 'chn-2013';

#lap_times_db(RACE_ID);
race_lap_diff(RACE_ID);

# TODO
# title from database

sub lap_times_db
{
    my $race_id = shift;
    my $times   = <<'TIMES';
SELECT secs
FROM race_lap_sec
WHERE no=? AND race_id=?
ORDER BY lap
TIMES

    # get race hash
    my $race = get_race($race_id);

    # titles for graph and terminal window
    my $year  = ( localtime $race->{epoch} )[5] + 1900;
    my $title = "$race->{gp} Grand Prix $year \\nLap Times";
    ( my $term_title = $title ) =~ s/\\n/ - /;

    # Create chart object and specify the properties of the chart
    my $chart = Chart::Gnuplot->new(
        terminal => qq!aqua title "$term_title" font "$graph_font" $dashed!,
        title    => $title,
        ylabel   => "Time (secs)",
        xlabel   => "Lap",
        ytics    => {
            labelfmt => "%5.3f",
        },
        grid => {
            linetype => 'dash',
            xlines   => 'off',
            ylines   => 'on',
        },
        yrange => '[] reverse',
        xrange => [ 1, $race->{laps} ],
        legend => {
            position => 'outside',
            align    => 'left',
            title    => 'Key',
        },
        key => qq!font "$legend_font"!,
    );

    # get lap times for selected drivers
    my $dbh = $db_session->();
    my $sth = $dbh->prepare($times);
    my @datasets;

    foreach ( 1 .. 10 ) {
        my $times =
          $dbh->selectcol_arrayref( $sth, { Columns => [1] },
            ( $_, $race_id ) );
        my $ds = Chart::Gnuplot::DataSet->new(
            xdata    => [ 1 .. scalar @$times ],
            ydata    => $times,
            title    => sprintf ("Driver %2d", $_), 
            style    => "lines",
            color    => $colours{$_},
            linetype => line_type($_),
        );
        push @datasets, $ds;
    }

    # close db handle
    $dbh->disconnect();

    #plot chart
    $chart->plot2d(@datasets);
}

sub race_lap_diff
{
    my $race_id = shift;

    # race winning time and numer of laps
    my $win_time = race_winner($race_id);

    # get a driver's lap times for comparison
    my $times   = <<'TIMES';
SELECT secs
FROM race_lap_sec
WHERE no=? AND race_id=?
ORDER BY lap
TIMES
    
    my $dbh = $db_session->();
    my $sth = $dbh->prepare($times);
    my @datasets;
    my $avg = $win_time->{avg};

    foreach ( 1 .. 10 ) {
        my $time =
        $dbh->selectcol_arrayref( $sth, { Columns => [1] },
            ( $_, $race_id ) );

        # create array ref of lap times differences
        my $run_tot;
        my $diff = [ map { $run_tot += $_ - $avg } @$time ];

        # create dataset
        my $ds = Chart::Gnuplot::DataSet->new(
            xdata    => [ 1 .. scalar @$diff ],
            ydata    => $diff,
            title    => sprintf ("Driver %2d", $_), 
            style    => "lines",
            color    => $colours{$_},
            linetype => line_type($_),
        );
        push @datasets, $ds;
    }

    # get race hash
    my $race = get_race($race_id);

    # titles for graph and terminal window
    my $year  = ( localtime $race->{epoch} )[5] + 1900;
    my $title = "$race->{gp} Grand Prix $year \\nRace Lap Differences";
    ( my $term_title = $title ) =~ s/\\n/ - /;

    # Create chart object and specify the properties of the chart
    my $chart = Chart::Gnuplot->new(
        terminal => qq!aqua title "$term_title" font "$graph_font" $dashed!,
        title    => $title,
        ylabel   => "Difference (secs)",
        xlabel   => "Lap",
        ytics    => {
            labelfmt => "%5.3f",
        },
        grid => {
            linetype => 'dash',
            xlines   => 'off',
            ylines   => 'on',
        },
        yrange => '[] reverse',
        xrange => [ 1, $race->{laps} ],
        legend => {
            position => 'outside',
            align    => 'left',
            title    => 'Key',
        },
        key => qq!font "$legend_font"!,
    );

    $chart->plot2d(@datasets);
}

# DATABASE
sub get_db_source
{
    my $src;

    if ($db_path) {
        $src = $db_path;
    }
    elsif ( my $env_file = $ENV{F1_TIMING_DB_PATH} ) {
        $src = $env_file;
    }
    else {
        $src = DB_PATH;
    }

    return $src;
}

sub db_connect
{
    my $db_source = 'dbi:SQLite:dbname=' . get_db_source;

    return connection_factory( $db_source, DB_USER, DB_PWD );
}

sub connection_factory
{
    my ( $db_source, $db_user, $db_pwd ) = @_;
    my $dbh;

    return sub {
        unless ( $dbh and $dbh->ping ) {
            $dbh = DBI->connect( $db_source, $db_user, $db_pwd )
              or die "$DBI::errstr\n";
            $dbh->{AutoCommit} = 0;
            $dbh->{RaiseError} = 1;
            $dbh->do("PRAGMA foreign_keys = ON");
        }
        $dbh;
      }
}

sub get_race
{
    my $id = shift;

    my $sql = <<'SQL';
SELECT id, rd, date, gp, laps, strftime('%s',date) AS epoch
FROM race
WHERE id=?
SQL

    my $href;
    my $dbh = $db_session->();
    my $sth = $dbh->prepare($sql);
    $sth->execute($id);

    unless ( $href = $sth->fetchrow_hashref ) {
        if ( $sth->err ) {
            warn "Database error: $sth->errstr\n";
        }
        else {
            $href = {};
        }
    }

    return $href;
}

sub line_type
{
    my $no = shift;

    $no % 2
      ? $no < 13
          ? 'solid'
          : 'dash'
      : $no > 13 ? 'solid'
      :            'dash';

}

sub race_winner
{
    my $race_id = shift;
    my $dbh = $db_session->();

    my $sql   = <<'SQL';
SELECT total_time, laps
FROM race_classification
WHERE race_id=? AND pos=1
SQL

    my $win = $dbh->selectrow_hashref($sql, {}, $race_id);
    my ($h, $m, $s, $f) = $win->{total_time} =~ /(\d):(\d\d):(\d\d)\.(\d{1,3})/;
    my $secs = ($h * 60 + $m) * 60 + $s + $f / 1_000;

    $win->{secs} = $secs;
    $win->{avg} = $secs / $win->{laps};

    return $win;
}
