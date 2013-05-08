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

my $db_path = undef;

# database session handle

my $db_session = db_connect();

#lap_times_demo();
lap_times_db();

sub lap_times_db
{
    my $no    = 10;
    my $id    = 'chn-2013';
    my $times = <<'TIMES';
SELECT lap, secs
FROM race_lap_sec
WHERE no=? AND race_id=?
ORDER BY lap
TIMES

    my $dbh = $db_session->();
    my $ytimes =
      $dbh->selectcol_arrayref( $times, { Columns => [2] }, ( $no, $id ) );
    my $xlaps = [ 1 .. scalar @$ytimes ];

    # Create chart object and specify the properties of the chart
    my $chart = Chart::Gnuplot->new(
        terminal => 'aqua',
        title    => "Lap Times ($id)",
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
        xrange => [ 1, scalar @$xlaps ],
    );

    # Create dataset object and specify the properties of the dataset
    my $dataSet = Chart::Gnuplot::DataSet->new(
        xdata => $xlaps,
        ydata => $ytimes,
        title => "Driver $no",
        style => "lines",
    );

    # Plot the data set on the chart
    $chart->plot2d($dataSet);
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
