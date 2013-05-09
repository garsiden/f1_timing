#! /usr/bin/env perl

use DBI;
use Data::Dumper;
use Chart::Gnuplot;
#use POSIX qw(strftime);

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

#lap_times_demo();
lap_times_db();

# TODO
# multi-plot
# legend
# car colours
# title from database

sub lap_times_db
{
    my $race_id = 'chn-2013';
    my $font    = 'Monaco, 12';
    my $dashed  = 'dashed';       # solid|dashed
    my $times   = <<'TIMES';
SELECT lap, secs
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
        terminal => qq!aqua title "$term_title" font "$font" $dashed!,
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
        key => 'font "Monaco, 10"',
    );

    # get lap times for selected driver
    my $dbh = $db_session->();
    my $sth = $dbh->prepare($times);
    my @datasets;

    foreach ( 1 .. 4, 10 ) {
        my $times =
          $dbh->selectcol_arrayref( $sth, { Columns => [2] },
            ( $_, $race_id ) );
        my $ds = Chart::Gnuplot::DataSet->new(
            xdata    => [ 1 .. scalar @$times ],
            ydata    => $times,
            title    => "Driver $_",
            style    => "lines",
            color    => $colours{$_},
            linetype => $_ % 2 ? 'solid' : 'dash',
        );
        push @datasets, $ds;
    }

    # close db handle
    $dbh->disconnect();

    #plot chart
    $chart->plot2d(@datasets);
}

sub lap_times_demo
{
    # Data
    my @ytimes = (
        96.345, 96.567, 97.765, 97.321, 96.987, 96.589,
        96.123, 96.476, 95.987, 96.001
    );
    my @xlaps = ( 1 .. 10 );

    # Create chart object and specify the properties of the chart
    my $chart = Chart::Gnuplot->new(
        terminal => 'aqua',
        title    => "Lap Times (Demo)",
        ylabel   => "Time (secs)",
        xlabel   => "Lap",
        ytics    => {
            labelfmt => "%5.3f",
        },
    );

    # Create dataset object and specify the properties of the dataset
    my $dataSet = Chart::Gnuplot::DataSet->new(
        xdata => \@xlaps,
        ydata => \@ytimes,
        title => "Driver 1",
        style => "lines",

    );

    # Plot the data set on the chart
    $chart->plot2d($dataSet);
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

