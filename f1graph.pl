#! /usr/bin/env perl

use DBI;
use Data::Dumper;
use Chart::Gnuplot;
use Getopt::Long;
use Pod::Usage;
use File::Spec::Functions qw(:DEFAULT splitpath );
use Hash::Merge qw(merge);

use strict;
use warnings;
use 5.012;

# config constants
use constant SEASON    => '2013';
use constant DOCS_DIR  => "$ENV{HOME}/Documents/F1/";
use constant GRAPH_DIR => DOCS_DIR . SEASON . '/Graphs/';

# database constants
use constant DB_PATH => "$ENV{HOME}/Documents/F1/" . SEASON
  . '/db/f1_timing.db';
use constant DB_PWD  => q{};
use constant DB_USER => q{};

# graph global constants
use constant AQUA_FONT       => 'Andale Mono';
use constant AQUA_TITLE_FONT => 'Verdana';
use constant PNG_FONT        => 'Monaco';
use constant PNG_TITLE_FONT  => "Vera";
use constant DASHED          => 'dashed';        # solid|dashed

# database session handle
my $db_session = db_connect();

my %colours = (
    1,  "#020138", 2,  "#485184", 3,  "#B80606", 4,  "#B80606", 5,  "#B7BACC",
    6,  "#D0D7DF", 7,  "#F8A62D", 8,  "#F9D61A", 9,  "#72A5A6", 10, "#A7C8C9",
    11, "#646564", 12, "#989898", 14, "#B2C61B", 15, "#D6E741", 16, "#3F62A6",
    17, "#6E94C0", 18, "#640F6F", 19, "#A36FAA", 20, "#076214", 21, "#7EAE7B",
    22, "#ED528A", 23, "#F5AAC4",
);

use constant VERSION => '20130513';

# command line option variables
my $race_id = undef;
my $term    = undef;
my $graph   = undef;
my $outdir  = undef;
my $version = 0;

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
    'term=s'    => \$term,
    't=s'       => \$term,
    'graph=s'   => \$graph,
    'g=s'       => \$graph,
    'o=s'       => \$graph,
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
$term    ||= 'aqua';
$outdir  ||= GRAPH_DIR;
$season  ||= (localtime)[5] + 1900;
$race_id ||= get_current_race()->{id};
$race_id .= "-$season";

if ($help) { pod2usage(2) }
elsif ($man) { pod2usage( -verbose => 2 ) }

# elsif ( defined $timing )   { get_timing() }
# elsif ( defined $import )   { db_import($import) }
# elsif ( defined $calendar ) { show_calendar($calendar) }
# elsif ( defined $export ) { export( $export, $race_id ) }
elsif ($version) { print "$0 v@{[VERSION]}\n"; exit }

# closures for tables
my $graph_tab = get_graph_table();
my $GR        = &$graph_tab->{$graph};
my $term_tab  = get_term_table();

# run graphing sub
$GR->{grapher}($race_id);

# TODO
# see if possible to make last x axis tick no of race laps
# title from database

sub race_lap_times
{
    my $race_id = shift;

    # get race classification
    my $race_class = race_class($race_id);
    my $laps       = $race_class->[0]{laps};

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
            color    => $colours{$no},
            linetype => line_type($no),
            width    => 1,
        );
        push @datasets, $ds;
    }

    $sth->finish;

    # get race hash
    my $race = get_race($race_id);

    # titles for graph and terminal window
    my $year  = ( localtime $race->{epoch} )[5] + 1900;
    my $title = "$race->{gp} Grand Prix $year \\nLap Times";

    # set up required terminal & output
    my $tm       = &$term_tab->{$term};
    my $terminal = qq|$tm->{type} font "$tm->{term_font}" $tm->{dash}|;
    my $output   = undef;

    if ( $term eq 'aqua' ) {
        ( my $term_title = $title ) =~ s/\\n/ - /;
        $terminal .= qq| title "$term_title"|;
    }
    elsif ( $term = 'png' ) {
        my $outfile = substr( $race_id, 0, 3 ) . "-$GR->{output}.png";
        $output = catdir( $outdir, $outfile );
    }

    # Create chart object and specify the properties of the chart
    my $base_opts = $GR->{options};
    my %cust_opts      = (
        terminal => $terminal,
        title    => {
            text => $title,
            font => $tm->{title_font},
        },
        xrange    => [ 1, $laps ],
        key       => qq|font "$tm->{key_font}"|,
        timestamp => {
            font => $tm->{time_font},
        },
    );

    # merge option hashes
    # my %options = %{ merge( $base_opts, \%cust_opts ) };
    my $options = merge( $base_opts, \%cust_opts );

    # create and plot chart
    my $chart = Chart::Gnuplot->new(%$options);
    $chart->{output} = $output if $output;
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
            color    => $colours{$no},
            linetype => line_type($no),
            width    => 2,
        );
        push @datasets, $ds;
    }
    $sth->finish;

    # get race hash
    my $race = get_race($race_id);

    # titles for graph and terminal window
    my $year  = ( localtime $race->{epoch} )[5] + 1900;
    my $title = "$race->{gp} Grand Prix $year \\nRace Lap Differences";

    ( my $term_title = $title ) =~ s/\\n/ - /;

    # set up required terminal
    my ( $terminal, $term_font, $key_font, $title_font, $time_font, $dashed );
    my $outfile;
    my $output = undef;

    if ( $term eq 'aqua' ) {
        $term_font  = AQUA_FONT . ',12';
        $key_font   = AQUA_FONT . ',10';
        $title_font = AQUA_TITLE_FONT . ' Bold,12';
        $time_font  = AQUA_FONT . ',9';
        $dashed     = DASHED;
        $terminal =
          qq|aqua title "$term_title" font "$term_font" $dashed size "946,594"|;
    }
    elsif ( $term eq 'png' ) {
        $term_font  = PNG_FONT . ',9';
        $key_font   = PNG_FONT . ',7';
        $title_font = PNG_TITLE_FONT . ',14';
        $time_font  = PNG_FONT . ',7';
        $dashed     = DASHED;
        $terminal   = qq|pngcairo font "$term_font" $dashed|;
        $outfile    = substr( $race_id, 0, 3 ) . '-race-lap-diff.png';
        $output     = catdir( $outdir, $outfile );
    }
    else {
        die "Terminal type '$term' not recognized\n";
    }

    # Create chart object and specify the properties of the chart
    my $chart = Chart::Gnuplot->new(
        terminal => $terminal,
        bg       => 'white',
        title    => {
            text => $title,
            font => $title_font,
        },
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
        xrange => [ 1, $laps ],
        legend => {
            position => 'outside',
            align    => 'left',
            title    => 'Key',
        },
        imagesize => "1000,600",
        timestamp => {
            fmt  => '%a, %d %b %Y %H:%M:%S',
            font => $time_font,
        },
        key => qq|font "$key_font"|,
    );

    $chart->{output} = $output if $output;
    $chart->plot2d(@datasets);

    # $chart->convert('pdf');

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
                    title   => 'My Title',
                    grapher => \&race_lap_diff,
                    output  => 'race-lap-diff',
                },
                'race-lap-times' => {
                    title   => 'My Title',
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

sub get_term_table
{
    my $term_href;

    return sub {
        unless ($term_href) {

            $term_href = {
                aqua => {
                    type       => 'aqua',
                    term_font  => AQUA_FONT . ',12',
                    key_font   => AQUA_FONT . ',10',
                    title_font => AQUA_TITLE_FONT . ' Bold,12',
                    time_font  => AQUA_FONT . ',9',
                    dash       => DASHED,
                },
                png => {
                    type       => 'pngcairo',
                    term_font  => PNG_FONT . ',9',
                    key_font   => PNG_FONT . ',7',
                    title_font => PNG_TITLE_FONT . ',14',
                    time_font  => PNG_FONT . ',7',
                    dash       => DASHED,
                },
            };
        }
    };
}

END { $db_session->()->disconnect }
