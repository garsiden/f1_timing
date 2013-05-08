#! /usr/bin/env perl

use DBI;
use Data::Dumper;

use strict;
use warnings;

# config constants
use constant SEASON   => '2013';
use constant DOCS_DIR => "$ENV{HOME}/Documents/F1/";

# database constants
use constant DB_PATH => "$ENV{HOME}/Documents/F1/" . SEASON
  . '/db/f1_timing.db';
use constant DB_PWD  => q{};
use constant DB_USER => q{};

use Chart::Gnuplot;

lap_times_demo();

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
