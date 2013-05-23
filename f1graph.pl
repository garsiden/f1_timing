#! /usr/bin/env perl

use DBI;
use Data::Dumper;
use Chart::Gnuplot;
use Getopt::Long;
use Pod::Usage;
use File::Spec::Functions qw(:DEFAULT splitpath );
use Hash::Merge qw(merge);
use Const::Fast;

use strict;
use warnings;
use 5.012;

# config constants
const my $SEASON    => '2013';
const my $DOCS_DIR  => "$ENV{HOME}/Documents/F1";
const my $GRAPH_DIR => "$DOCS_DIR/$SEASON/Graphs";

# database constants
const my $DB_PATH => "$DOCS_DIR/$SEASON/db/f1_timing.db";
const my $DB_PWD  => q{};
const my $DB_USER => q{};

# graph global constants
const my $AQUA_FONT       => 'Andale Mono';
const my $AQUA_TITLE_FONT => 'Verdana';
const my $PNG_FONT        => 'Monaco';
const my $PNG_TITLE_FONT  => "Vera";
const my $DASHED          => 'dashed';        # solid|dashed
const my %COLOURS         => (
    1,  "#020138", 2,  "#485184", 3,  "#B80606", 4,  "#B80606", 5,  "#B7BACC",
    6,  "#D0D7DF", 7,  "#F8A62D", 8,  "#F9D61A", 9,  "#72A5A6", 10, "#A7C8C9",
    11, "#646564", 12, "#989898", 14, "#B2C61B", 15, "#D6E741", 16, "#3F62A6",
    17, "#6E94C0", 18, "#640F6F", 19, "#A36FAA", 20, "#076214", 21, "#7EAE7B",
    22, "#ED528A", 23, "#F5AAC4",
);

const my $VERSION => '20130513';

# database session handle
my $db_session = db_connect();

# command line option variables
my $race_id  = undef;
my $term_id  = undef;
my $graph_id = undef;
my $outdir   = undef;
my $version  = 0;

# TODO
my $season  = undef;
my $quiet   = 0;
my $db_path = undef;
my $help    = 0;
my $man     = 0;

Getopt::Long::Configure qw( no_auto_abbrev bundling);
GetOptions(
    'race-id=s' => \$race_id,
    'r=s'       => \$race_id,
    'term=s'    => \$term_id,
    't=s'       => \$term_id,
    'graph=s'   => \$graph_id,
    'g=s'       => \$graph_id,
    'o=s'       => \$outdir,
    'outdir=s'  => \$outdir,
    'version'   => \$version,

    # TODO
    'season=s'  => \$season,
    's=s'       => \$season,
    'db-path=s' => \$db_path,
    'quiet'     => \$quiet,
    'q'         => \$quiet,
    'help'      => \$help,
    'man'       => \$man,
) or pod2usage();

# Process command-line arguments
#
# use default options if none specified
$term_id ||= 'aqua';
$outdir  ||= $GRAPH_DIR;
$season  ||= (localtime)[5] + 1900;
$race_id ||= get_current_race()->{id};
$race_id .= "-$season";

if ($help) { pod2usage(2) }
elsif ($man) { pod2usage( -verbose => 2 ) }

# elsif ( defined $timing )   { get_timing() }
# elsif ( defined $import )   { db_import($import) }
# elsif ( defined $calendar ) { show_calendar($calendar) }
# elsif ( defined $export ) { export( $export, $race_id ) }
elsif ($version) { print "$0 v$VERSION}\n"; exit }

# closures for tables
my $term_tab  = get_term_table();
my $graph_tab = get_graph_table();
my $graph     = &$graph_tab->{$graph_id};

# run graphing sub
$graph->{grapher}($race_id);

# TODO
# see if possible to make last x axis tick no of race laps
# title from database

sub race_lap_times
{
    my $race_id = shift;

    # get race classification
    my $race_class = race_class($race_id);
    my $laps       = $race_class->[0]{laps};

    my $time_sql = <<'TIMES';
SELECT secs
FROM race_lap_sec
WHERE no=? AND race_id=?
ORDER BY lap
TIMES

    # get lap times for classified drivers
    my $dbh = $db_session->();
    my $sth = $dbh->prepare($time_sql);

    my @datasets;
    foreach ( @$race_class[ 0 .. 9 ] ) {
        my $no   = $_->{no};
        my $time = $dbh->selectcol_arrayref(
            $sth,
            { Columns => [1] },
            ( $no, $race_id )
        );

        # create dataset
        my $ds = Chart::Gnuplot::DataSet->new(
            xdata    => [ 1 .. scalar @$time ],
            ydata    => $time,
            title    => substr( $_->{driver}, 3 ),
            style    => "lines",
            color    => $COLOURS{$no},
            linetype => line_type($no),
            width    => 1,
        );
        push @datasets, $ds;
    }

    $sth->finish;

    # set any chart dataset options
    my $cust_opts = { xrange => [ 1, $laps ], };

    # create and plot chart
    my $chart = create_chart($cust_opts);
    $chart->plot2d(@datasets);
}

sub race_lap_times_fuel_adj
{
    my $race_id = shift;

    # get race classification
    my $race_class = race_class($race_id);
    my $laps       = $race_class->[0]{laps};

    # get race data
    my $data = get_race_data($race_id);
    my $adj_per_lap =
      $data->{fuel_effect_10kg} / 10 * $data->{fuel_consumption_kg};

    my $times = <<'TIMES';
SELECT secs
FROM race_lap_sec
WHERE no=? AND race_id=?
ORDER BY lap
TIMES

    # get lap times for classified drivers
    my $dbh = $db_session->();
    my $sth = $dbh->prepare($times);

    my @datasets;
    foreach ( @$race_class[ 0 .. 9 ] ) {
        my $no    = $_->{no};
        my $nlaps = $laps;
        my $time  = $dbh->selectcol_arrayref(
            $sth,
            { Columns => [1] },
            ( $no, $race_id )
        );

        my @adjusted = map { $_ - $adj_per_lap * --$nlaps } @$time;

        # create dataset
        my $ds = Chart::Gnuplot::DataSet->new(
            xdata    => [ 1 .. scalar @adjusted ],
            ydata    => \@adjusted,
            title    => substr( $_->{driver}, 3 ),
            style    => "lines",
            color    => $COLOURS{$no},
            linetype => line_type($no),
            width    => 1,
        );
        push @datasets, $ds;
    }

    $sth->finish;

    # Set any chart dataset options
    my $cust_opts = { xrange => [ 1, $laps ], };

    # create and plot chart
    my $chart = create_chart($cust_opts);
    $chart->plot2d(@datasets);
}

sub race_lap_diff
{
    my $race_id = shift;

    # get  winner's lap times for comparison
    my $race_class = race_class($race_id);
    my $total_secs = $race_class->[0]{secs};
    my $laps       = $race_class->[0]{laps};
    my $avg        = $total_secs / $laps;

    # get classified drivers' lap times
    my $time_sql = <<'TIMES';
SELECT secs
FROM race_lap_sec
WHERE no=? AND race_id=?
ORDER BY lap
TIMES

    my $dbh = $db_session->();
    my $sth = $dbh->prepare($time_sql);
    my @datasets;

    foreach ( @$race_class[ 0 .. 9 ] ) {
        my $no   = $_->{no};
        my $time = $dbh->selectcol_arrayref(
            $sth,
            { Columns => [1] },
            ( $no, $race_id )
        );

        # create array ref of lap times differences
        my $run_tot;
        my $diff = [ map { $run_tot += $avg - $_ } @$time ];

        # create dataset
        my $ds = Chart::Gnuplot::DataSet->new(
            xdata    => [ 1 .. scalar @$diff ],
            ydata    => $diff,
            title    => substr( $_->{driver}, 3 ),
            style    => "lines",
            color    => $COLOURS{$no},
            linetype => line_type($no),
            width    => 2,
        );
        push @datasets, $ds;
    }
    $sth->finish;

    # set any chart dataset options
    my $cust_opts = { xrange => [ 1, $laps ], };

    # create and plot chart
    my $chart = create_chart($cust_opts);
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
        $src = $DB_PATH;
    }

    return $src;
}

sub db_connect
{
    my $db_source = 'dbi:SQLite:dbname=' . get_db_source;

    return connection_factory( $db_source, $DB_USER, $DB_PWD );
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

sub race_class
{
    my $race_id = shift;
    my $dbh     = $db_session->();

    my $sql = <<'SQL';
SELECT pos, no, driver, total_time, laps
FROM race_classification
WHERE race_id=? AND pos
ORDER BY pos ASC
SQL

    my $class = $dbh->selectall_arrayref( $sql, { Slice => {} }, $race_id );

    foreach (@$class) {
        $_->{secs} = secsftime( $_->{total_time} );
    }

    return $class;
}

sub secsftime
{
    my $time = shift;

    my ( $h, $m, $s, $f ) = $time =~ /(\d):(\d\d):(\d\d)\.(\d{1,3})/;
    my $secs = ( $h * 60 + $m ) * 60 + $s + $f / 1_000;

    return $secs;
}

sub get_current_race
{
    my ( $sql, $href );

    $sql = "SELECT rd, id FROM current_race";
    my $dbh = $db_session->();
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    unless ( $href = $sth->fetchrow_hashref ) {
        if ( $sth->err ) {
            warn "Database error: $sth->errstr\n";
        }
    }

    return $href;
}

sub get_graph_table
{
    my $graph_href;

    return sub {
        unless ($graph_href) {
            $graph_href = {
                'race-lap-diff' => {
                    title   => 'Race Lap Differences',
                    grapher => \&race_lap_diff,
                    output  => 'race-lap-diff',
                    options => {
                        bg     => 'white',
                        ylabel => "Difference (secs)",
                        xlabel => "Lap",
                        ytics  => {
                            labelfmt => "%5.3f",
                        },
                        grid => {
                            linetype => 'dash',
                            xlines   => 'off',
                            ylines   => 'on',
                            color    => 'grey',
                            width    => 1,
                        },
                        legend => {
                            position => 'outside',
                            align    => 'left',
                            title    => 'Key',
                        },
                        timestamp => {
                            fmt => '%a, %d %b %Y %H:%M:%S',
                        },
                        imagesize => '900,600',
                    }
                },
                'race-lap-times' => {
                    title   => 'Race Lap Times',
                    grapher => \&race_lap_times,
                    output  => 'race-lap-times',
                    options => {
                        bg     => 'white',
                        ylabel => "Time (secs)",
                        xlabel => "Lap",
                        ytics  => {
                            labelfmt => "%5.3f",
                        },
                        grid => {
                            linetype => 'dash',
                            xlines   => 'off',
                            ylines   => 'on',
                            color    => 'grey',
                            width    => 1,
                        },
                        yrange => '[] reverse',
                        legend => {
                            position => 'outside',
                            align    => 'left',
                            title    => 'Key',
                        },
                        timestamp => {
                            fmt => '%a, %d %b %Y %H:%M:%S',
                        },
                        imagesize => '900,600',
                    },
                },
                'race-lap-times-fuel-adj' => {
                    title   => 'Race Lap Times (Fuel Adjusted)',
                    grapher => \&race_lap_times_fuel_adj,
                    output  => 'race-lap-times-fuel_adj',
                    options => {
                        bg     => 'white',
                        ylabel => "Time (secs)",
                        xlabel => "Lap",
                        ytics  => {
                            labelfmt => "%5.3f",
                        },
                        grid => {
                            linetype => 'dash',
                            xlines   => 'off',
                            ylines   => 'on',
                            color    => 'grey',
                            width    => 1,
                        },
                        yrange => '[] reverse',
                        legend => {
                            position => 'outside',
                            align    => 'left',
                            title    => 'Key',
                        },
                        timestamp => {
                            fmt => '%a, %d %b %Y %H:%M:%S',
                        },
                        imagesize => '900,600',
                    },
                },
            };
            return $graph_href;
        }
    };
}

sub get_drivers
{
    my $race_id = shift;

    my $driver_sql = <<'DRIVERS';
SELECT no, name
FROM race_driver
WHERE race_id=?
DRIVERS

    my $dbh = $db_session->();
    my $sth = $dbh->prepare($driver_sql);
    my %drivers =
      @{ $dbh->selectcol_arrayref( $sth, { Columns => [ 1, 2 ] }, ($race_id) )
      };
    $sth->finish;
    print Dumper \%drivers;

    return \%drivers;
}

sub get_race_data
{
    my $race_id = shift;
    my $dbh     = $db_session->();

    my $sql = <<'SQL';
SELECT fuel_consumption_kg, fuel_effect_10kg, fuel_total_kg
FROM race_data
WHERE race_id=?
SQL

    my $data = $dbh->selectrow_hashref( $sql, {}, $race_id );

    return $data;
}

sub get_term_table
{
    my $term_href;

    return sub {
        unless ($term_href) {

            $term_href = {
                aqua => {
                    type       => 'aqua',
                    term_font  => "$AQUA_FONT,12",
                    key_font   => "$AQUA_FONT,10",
                    title_font => "$AQUA_TITLE_FONT Bold,12",
                    time_font  => "$AQUA_FONT,9",
                    dash       => $DASHED,
                },
                png => {
                    type       => 'pngcairo',
                    term_font  => "$PNG_FONT,9",
                    key_font   => "$PNG_FONT,7",
                    title_font => "$PNG_TITLE_FONT,14",
                    time_font  => "$PNG_FONT,7",
                    dash       => $DASHED,
                },
            };
        }
    };
}

sub create_chart
{
    my ($cust_opts) = @_;

    # get race hash
    my $race = get_race($race_id);

    # titles for graph and terminal window
    my $year  = ( localtime $race->{epoch} )[5] + 1900;
    my $title = "$race->{gp} Grand Prix $year \\n$graph->{title}";

    # set up required terminal & output
    my $tm       = &$term_tab->{$term};
    my $terminal = qq|$tm->{type} font "$tm->{term_font}" $tm->{dash}|;
    my $output   = undef;

    if ( $term_id eq 'aqua' ) {
        ( my $term_title = $title ) =~ s/\\n/ - /;
        $terminal .= qq| title "$term_title"|;
    }
    elsif ( $term_id = 'png' ) {
        my $outfile = substr( $race_id, 0, 3 ) . "-$graph->{output}.png";
        $output = catdir( $outdir, $outfile );
    }

    # Create chart object and specify the properties of the chart
    my $base_opts = $graph->{options};
    my $var_opts  = {
        terminal => $terminal,
        title    => {
            text => $title,
            font => $tm->{title_font},
        },
        key       => qq|font "$tm->{key_font}"|,
        timestamp => {
            font => $tm->{time_font},
        },
    };

    # merge option hashes
    my $options = merge( merge( $base_opts, $var_opts ), $cust_opts );

    # create
    my $chart = Chart::Gnuplot->new(%$options);
    $chart->{output} = $output if $output;

    return $chart;
}

END { $db_session->()->disconnect }
