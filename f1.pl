#! /usr/bin/env perl

use DBI;
use LWP::Simple;
use HTML::LinkExtor;
use Term::ReadKey;
use Getopt::Long;
use Pod::Usage;
use File::Spec::Functions;
use Data::Dumper;

use strict;
use warnings;

# config constants
use constant DOCS_DIR    => "$ENV{HOME}/Documents/F1/2011/";
use constant CONVERTER   => 'pdftotext';
use constant CONVERT_OPT => '-layout';
use constant EXPORTER    => 'sqlite3';
use constant EXPORT_OPT  => '-csv -header';
use constant TIMING_BASE => 'http://fia.com/en-GB/mediacentre/f1_media/Pages/';
use constant TIMING_PAGE => 'timing.aspx';

# previous FIA web address
#  'http://fialive.fiacommunications.com/en-GB/mediacentre/f1_media/Pages/';

# database constants
use constant DB_PATH => "$ENV{HOME}/Documents/F1/2011/db/f1_timing.db";
use constant DB_PWD  => q{};
use constant DB_USER => q{};

use constant VERSION => '20110612';

# command line option variables
my $timing      = undef;
my $update      = undef;
my $export      = undef;
my $export_opts = undef;
my $race_id     = undef;
my $calendar    = undef;
my $docs_dir    = undef;
my $quiet       = 0;
my $db_path     = undef;
my $help        = 0;
my $man         = 0;
my $version     = 0;

# test/debug
my $debug = 0;
my $test  = 0;

Getopt::Long::Configure qw( no_auto_abbrev bundling);
GetOptions(
    'timing:s'      => \$timing,
    't:s'           => \$timing,
    'update:s'      => \$update,
    'u:s'           => \$update,
    'export:s'      => \$export,
    'e:s'           => \$export,
    'export-opts=s' => \$export_opts,
    'race-id=s'     => \$race_id,
    'r=s'           => \$race_id,
    'calendar:i'    => \$calendar,
    'c:i'           => \$calendar,
    'db-path=s'     => \$db_path,
    'docs-dir=s'    => \$docs_dir,
    'quiet'         => \$quiet,
    'q'             => \$quiet,
    'help'          => \$help,
    'man'           => \$man,
    'version'       => \$version,
    'test'          => \$test,
    'debug'         => \$debug,
) or pod2usage(2);

# shared regexs
my $driver_re  = q<[A-Z]\. [A-Z '-]+?>;
my $entrant_re = q<[A-z0-9& -']+>;
my $time_re    = '\d:\d\d\.\d\d\d';
my $kph_re     = '\d{2,3}\.\d{1,3}';
my $pos_re     = '\d{1,2}';
my $no_re      = $pos_re;
my $lap_re     = '\d{1,2}';
my $tod_re     = '\d\d:\d\d:\d\d';
my $nat_re     = '[A-Z]{3}';

# PDF mappings
my $pdf_href = undef;

# helper subs
use subs qw ( get_docs_dir get_pdf_map get_db_source get_export_map
  get_doc_sessions db_connect);

# database session handle
my $db_session = db_connect;

# Process command-line arguments
#
# use default options if none specified
unless ($export_opts) { $export_opts = EXPORT_OPT }

if    ($help)               { pod2usage(2) }
elsif ($man)                { pod2usage( -verbose => 2 ) }
elsif ($timing)             { get_timing() }
elsif ( defined $update )   { update_db($update) }
elsif ( defined $calendar ) { show_calendar($calendar) }
elsif ( defined $export ) { export( $export, $race_id ) }
elsif ($version)          { print "$0 v@{[VERSION]}\n" }
elsif ($test) {
    show_exports();
}

# download timing PDFs from FIA web site
sub get_timing
{
    my $check_exists = 1;
    my ($race, $get_docs, $msg);

    # get list of latest pdfs
    my $docs = get_doc_links( TIMING_BASE, TIMING_PAGE );

    scalar @$docs > 0
      or die "No timing data currently available.\n";

    $$docs[0] =~ /([a-z123-]+.pdf$)/;    # get race prefix of first PDF
    $race = substr $1, 0, 3;

    unless ( length $timing ) {
        $get_docs = $docs;
    }
    else {
        my $sess_href = get_doc_sessions
        my $arg = lc $timing;
        defined( my $re = $sess_href->{$arg} )
          or die "$timing timing option not recognized\n";

        $get_docs = [ grep /$re/, @$docs ];
    }

    print Dumper $get_docs if $debug;

    my $src_dir = get_docs_dir;
    my $race_dir = catdir( $src_dir, $race );

    unless ( -d $race_dir ) {
        mkdir $race_dir
          or die "Unable to create directory $race_dir: $! $?\n";
        $check_exists = 0;
    }

    foreach (@$get_docs) {
        ( my $pdf ) = /([a-z123-]+.pdf$)/;
        my $dest = catfile( $race_dir, $pdf );
        print Dumper $dest if $debug;
        if ( $check_exists and -f $dest ) {
            print "File $dest already exists.\n";
            print "Overwrite? ([y]es/[n]o/[a]ll/[c]ancel)";
            print "\n" if $^O =~ /MSWin/;
            ReadMode 'cbreak';
            my $answer = lc ReadKey(0);
            ReadMode 'normal';

            while ( index( 'ynac', $answer ) < 0 ) {
                print "\nPlease enter [y]es/[n]o/[a]ll/[c]ancel)?";
                print "\n" if $^O =~ /MSWin/;
                ReadMode 'cbreak';
                $answer = lc ReadKey(0);
                ReadMode 'normal';
            }

            print "\n";
            if    ( $answer eq 'c' ) { exit; }
            elsif ( $answer eq 'n' ) { next; }
            elsif ( $answer eq 'a' ) { $check_exists = 0; }
        }
        my $src = TIMING_BASE . $_;
        if ( ( my $rc = getstore( $src, $dest ) ) == RC_OK ) {
            print "Downloaded $pdf.\n" unless $quiet;
        }
        else {
            warn "Error downloading $pdf. (Error code: $rc)\n";
        }
    }
}

sub get_docs_dir
{
    if ($docs_dir) { return $docs_dir }
    elsif ( my $env = $ENV{F1_TIMING_DOCS_DIR} ) { return $env }
    else                                         { return DOCS_DIR }
}

sub get_doc_sessions
{
    my %h = (
        p1  => qr/session1/,
        p2  => qr/session2/,
        p3  => qr/session3/,
        p   => qr/session[123]/,
        q   => qr/qualifying/,
        r   => qr/race/,
        fri => qr/session[12]/,
        sat => qr/session3|qualifying/,
    );
    $h{thu} = $h{fri};
    $h{sun} = $h{r};

    \%h;
}

sub update_db
{
    my $arg = shift;

    my ( $race, $session, $timesheet, $pdf_href );
    my $pdf_map = get_pdf_map;
    my $len     = length $arg;
    my $sess_href = get_doc_sessions;

    my ( $r, $s );
    if ( $len == 0 ) {
        my @sorted = map {
            my $re = qr/$_/;
            sort grep /$re/, keys %$pdf_map
        } qw( ^s ^q ^r );
        print "$0 update options:\n\n";
        print "Provide a three letter race id or choose from the following:";
	print "or choose from the following:";
        print "\n\t", join( "\n\t", @sorted ), "\n";
        return;
    }
    elsif (( ( $race, $session ) = map lc, split /-/, $arg )
        && defined $race
        && defined $session
        && defined( my $re = $sess_href->{$session} ) )
    {
        $pdf_href = { map { $_, $$pdf_map{$_} } grep /$re/, keys %$pdf_map };
    }
    elsif ( $len == 3 ) {
        $race    = $arg;
        $pdf_href = $pdf_map;
    }
    elsif ( $len > 3 ) {
        ((( $race, $timesheet ) = $arg =~ /^([a-z]{3})-(.+)$/) &&
        ($pdf_href = { $timesheet => $pdf_map->{$timesheet} }))
          or die "Timing document $arg not recognized\n";
    }
    else {
        die "Please provide an update argument of at least 3 characters\n";
    }

    my $race_dir = catdir( get_docs_dir, $race );
    my $year = 1900 + (localtime)[5];
    my $race_id = "$race-$year";

    for my $key ( keys %$pdf_href ) {
        my $src = catfile( $race_dir, "$race-$key.pdf" );
        -e $src or die "Error: file $src does not exist\n";

        # use two arg open method to get shell redirection to stdout
        my $pipe_cmd = qq<"@{[CONVERTER]}" @{[CONVERT_OPT]} "$src" - |>;

        open my $text, $pipe_cmd
          or die 'unable to open ' . CONVERTER . ": $!";

        my $href = $pdf_href->{$key};
        my ( $recs, $fk_recs ) = $href->{parser}($text);

        if ($fk_recs) {
            my $fk_table = $$href{fk_table};
            db_insert_array( $race_id, $fk_table, $fk_recs );
        }

        print Dumper($recs) if $debug;

        my $table = $href->{table};

        db_insert_array( $race_id, $table, $recs );
        close $text
          or die 'Unable to close ' . CONVERTER . ": $! $?";
    }
}

sub export
{
    my ( $value, $race_id ) = @_;
    my $map = get_export_map;

    unless ( length $value ) {
        show_exports($map);
        return;
    }

    my $src = $$map{$value}{src}
      or die "$value export not found";

    my $db  = get_db_source;
    my $sql = "SELECT * FROM $src";

    print Dumper $map if $debug;

    $sql .= " WHERE race_id='$race_id'" if $race_id;
    if ( my $order = $$map{$value}{order} ) { $sql .= " ORDER BY $order" }

    print "$sql\n" if $debug;

    my $pipe_cmd = qq <"> . EXPORTER . qq <" $export_opts "$db">;

    open my $exporter, "|-", $pipe_cmd
      or die "Unable to open " . EXPORTER . ": $!";

    print $exporter "$sql;";

    close $exporter
      or die "Error closing " . EXPORTER . ": $!";
}

sub race_history_chart
{
    my $text = shift;

    my $header_re = qr/LAP (\d{1,2})(?: {3,}|\n)/;
    my $gap_re    = '\d{1,3}\.\d\d\d';

    my $regex = qr/
    (?:                     # grouping for sub-patterns
        (?!                 # negative look ahead for no. field and a gap
            $no_re\ +       # car no
        )                   
        (\d*)               # may not be a space between no and gap fields
        (\d{3}\.\d{3})\  +  # when gap over 100s, so backtrack to get time   
        ($time_re)
    )
    |                       # sub-pattern for all other circumstances
        ($no_re)\ +
        (P)?                # field can be PIT, LAPS behind or gap in seconds
        (?:IT)?             # capture P, discard the rest
            (?:             # grouping for sub-pattern
                \d+\ [LAPS]{3,4}
            |
                $gap_re
            |
                \ +         # empty field on lap 1
            )?
         \ +
        ($time_re)
    /x;

    my ( @col_pos, $width, $prev_col, $len, $idx, $line, @recs );
    my @fields = qw(lap no  pit time);
    my @drivers;
    my $laptime;

  HEADER:
    while (<$text>) {
        if ( my @laps = /$header_re/g ) {

            #print Dumper \@laps if $debug;
            # skip empty lines
            do { $line = <$text> } until $line !~ /^\n$/;

            # split page into up to 5 lap columns
            @col_pos = ();
            while ( $line =~ m/(NO +GAP +TIME\s+)/g ) {
                push @col_pos, pos $line;
            }

          TIMES:
            while (<$text>) {
                next HEADER if /^\f/;
                redo HEADER if /$header_re/;
                next TIMES  if /^\n$/;
                $len = length;
                $prev_col = $idx = 0;
                for my $col (@col_pos) {
                    $width = $col - $prev_col;
                    if ( $prev_col < $len ) {
                        while ( substr( $_, $prev_col, $width ) =~ /$regex/g ) {
                            my ( $n, $p, $t );
                            if ($1) {
                                ( $n, $t ) = ( $1, $3 );
                            }
                            else {
                                ( $n, $p, $t ) = ( $4, $5, $6 );
                            }
                            my %temp;
                            @temp{@fields} = ( $laps[$idx], $n, $p, "00:0$t" );
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

sub provisional_starting_grid
{
    my $text = shift;

    my $left = qr/
        ($pos_re)\ +
        ($no_re)\ +
        ($driver_re)\**     # one or more asterisks indicate allowed to race
                            # although outside 107% of Q1 lap time.
        (?:\ {2,}|\n)       # two space gap to indicate end of name or new line
        ($time_re)?         # possibly no time set
    /x;

    my $right        = qr/($no_re) +($driver_re)\** +($time_re)? +($pos_re)/;
    my $entrant_line = qr/^ +($entrant_re)/;
    my ( $pos, $no, $driver, $time, $entrant, @recs );

    while (<$text>) {
        if (   ( ( $pos, $no, $driver, $time ) = /$left/ )
            || ( ( $no, $driver, $time, $pos ) = /$right/ ) )
        {
            ($entrant) = ( <$text> =~ /$entrant_line/ );
            push @recs,
              {
                'pos',     $pos,     'no',   $no, 'driver', $driver,
                'entrant', $entrant, 'time', $time
              };
        }
    }

    foreach (@recs) { print $$_{driver}, "\n" }
    return \@recs;
}

sub race_fastest_laps
{
    my @fields =
      qw( pos no driver nat entrant time on_lap gap kph time_of_day );
    my $aref = classification( @_, @fields );

    return $aref;
}

sub race_pit_stop_summary
{
    my $text = shift;

    my @fields =
      qw( no driver entrant lap time_of_day stop duration total_time );
    my $stop_re      = '\d';
    my $duration_re  = '(?:\d+:)?\d\d\.\d\d\d';
    my $totaltime_re = $duration_re;

    my $regex = qr/
       ($no_re)\ +
       ($driver_re)\ {2,}
       ($entrant_re?)\ +
       ($lap_re)\ + 
       ($tod_re)\ +
       ($stop_re)\ +
       ($duration_re)\ +
       ($totaltime_re)
    /x;

    print Dumper $regex if $debug;
    my @recs;

    while (<$text>) {
        my %hash;
        push @recs, \%hash if ( @hash{@fields} = /$regex/ );
    }

    return \@recs;
}

sub race_classification2
{
    my $text = shift;

    my $regex = qr/
        ($pos_re|DQ)?\ +            # POS
        ($no_re)\ +                 # NO
        ($driver_re)                # DRIVER
        \ *\**\ {2,}                # possible asterisk indicating penalty
        ($nat_re)\ +                # NAT
        ($entrant_re?)\ +           # ENTRANT
        ($lap_re)\ +                # LAPS completed
        (
            \d:\d\d:\d\d\.\d\d\d    # total TIME with hours
            |
            \d:\d\d\.\d\d\d         # total TIME, minutes
        )?\ *
        (                           # GAP group
            (?(7)                   # if a TIME has been set
                (?:
                    DNF                     # non finisher
                    |
                    \d{1,3}\.\d\d\d         # in seconds
                    |
                    \d{1,2}\ +[LAPS]{3,4}   # lap(s) behind
                )
                |DN[SF]$            # else DNS or finish a lap
            )
        )?\ *
        (?(7)                       # Only if TIME has been set
            (\d{2,3}\.\d\d\d)\ +    # KPH
            (\d:\d\d\.\d\d\d)\ +    # BEST
            (\d{1,2})$              # LAP to eol
        )
       /x;

    print Dumper $regex if $debug;

    my @recs;
    my @fields = qw( pos no driver nat entrant laps total_time
      gap kph best on_lap );

    while (<$text>) {
        last if /FASTEST LAP/;
        my %rec;
        if ( @rec{@fields} = /$regex/ ) { push @recs, \%rec }
    }

    return \@recs;

}

sub race_classification
{
    my $text = shift;

    my $regex = qr/
        ($pos_re|DQ)?\ +            # POS
        ($no_re)\ +                 # NO
        ($driver_re)                # DRIVER
        \ *\**\ {2,}                # possible asterisk indicating penalty
        ($nat_re)\ +                # NAT
        ($entrant_re?)\ +           # ENTRANT
        ($lap_re)\ +                # LAPS completed
        (
            \d:\d\d:\d\d\.\d\d\d    # total TIME with hours
            |
            \d{1,2}:\d\d\.\d\d\d    # total TIME, minutes
        )?\ *
        (                           # GAP group
            (?(?=DNS)               # look ahead condition
                DNS$                # eol anchor
                |
                (?:                 # grouping for GAP else
                    DNF                     # non finisher
                    |
                    \d{1,3}\.\d\d\d         # in seconds
                    |
                    \d{1,2}\ +[LAPS]{3,4}   # lap(s) behind
                )
            )
        )?\s+                       # no GAP for winner
        (?(7)                       # conditional on TIME
            (\d{2,3}\.\d\d\d)\ +    # KPH
            (\d:\d\d\.\d\d\d)\ +    # BEST
            (\d{1,2})$              # LAP to eol
        )
       /x;

    print Dumper $regex if $debug;

    my @recs;
    my @fields = qw( pos no driver nat entrant laps total_time
      gap kph best on_lap );

    while (<$text>) {
        last if /FASTEST LAP/;
        my %rec;
        if ( @rec{@fields} = /$regex/ ) { push @recs, \%rec }
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

    my $header_re  = qr/($no_re) +($driver_re)(?: {2,}|\n)/;
    my $laptime_re = qr/
        ($lap_re)\ *                # LAP
        (P)?\ +                     # PIT
        (?:                         # TIME - capture separately for formatting 
            (\d:\d\d\.\d\d\d)       # normal lap
            |
            (\d\d:\d\d:\d\d)        # time of day
            |
            (\d\d:\d\d\.\d\d\d)     # long - 2 digits for minutes
            |
            (\d:\d\d:\d\d\.\d\d\d)  # with hours for red flag
        )\s?
    /x;

    my ( @col_pos, $width, $prev_col, $len, $idx, $line, @recs );
    my @fields = qw(no lap pit time);
    my @drivers;

  HEADER:
    while (<$text>) {
        if ( my @header = /$header_re/g ) {
            my @nos;
            while ( my ( $no, $driver ) = splice( @header, 0, 2 ) ) {
                push @nos, { 'no', $no, 'name', $driver };
            }
            push @drivers, @nos;

            # skip empty lines
            do { $line = <$text> } until $line !~ /^\n$/;

            # split page into two time columns per driver
            @col_pos = ();
            while ( $line =~ m/((?:NO|LAP) +TIME\s+?){2}/g ) {
                push @col_pos, pos $line;
            }

          TIMES:
            while (<$text>) {
                next HEADER if /^\f/;
                redo HEADER if /$header_re/;
                next TIMES  if /^\n$/;
                $len = length;
                $prev_col = $idx = 0;
                for my $col (@col_pos) {
                    $width = $col - $prev_col;
                    if ( $prev_col < $len ) {
                        while (
                            substr( $_, $prev_col, $width ) =~ /$laptime_re/g )
                        {
                            my ( $l, $p ) = ( $1, $2 );
                            my $t;
                            if    ($3) { $t = "00:0$3" }
                            elsif ($4) { $t = $4 }
                            elsif ($5) { $t = "00:$5" }
                            elsif ($6) { $t = "0$6" }
                            my %temp;
                            @temp{@fields} = ( $nos[$idx]->{'no'}, $l, $p, $t );
                            push @recs, \%temp;
                        }
                        $prev_col = $col;
                        $idx++;
                    }
                }
            }
        }
    }

    # return times & drivers
    return \@recs, \@drivers;
}

# used by race fastest laps and practice session classification
sub classification
{
    my $text   = shift;
    my @fields = @_;
    my $gap_re = '\d{1,2}\.\d\d\d';

    my $regex = qr/
        ($pos_re)\ +
        ($no_re)\ +
        ($driver_re)\ +
        ($nat_re)\ +
        ($entrant_re?)\ +
        ($time_re)?\ *
        ($lap_re)\ *
        ($gap_re)?\ *
        ($kph_re)?\ *
        ($tod_re)?\s+
    /x;

    my @recs;

    while (<$text>) {
        my %hash;
        if ( @hash{@fields} = /$regex/ ) { push @recs, \%hash }
    }

    return \@recs;
}

sub practice_session_classification
{
    my @fields = qw( pos no driver nat entrant time laps gap kph time_of_day);
    my $recs = classification( @_, @fields );

    return $recs;
}

sub qualifying_classification
{
    my $text = shift;

    my $percent_re = '\d\d\d\.\d\d\d';
    my $laptime_re = "$time_re|DN[FS]";
    my $regex      = qr/
        ($pos_re)?\ +
        ($no_re)
        (?:\ +[A-Z].*?)
        ($time_re)\ *
        ($lap_re)?\ *
        ($percent_re)?\ *
        ($tod_re)?\s*
    /x;
    $regex .= qr/($time_re)? *($lap_re)? *($tod_re)?\s*/ x 2;

    print Dumper $regex if $debug;

    my @recs;
    my @fields = qw( pos no q1_time q1_laps percent q1_tod
      q2_time q2_laps q2_tod q3_time q3_laps q3_tod);

    while (<$text>) {
        last if /POLE POSITION LAP/;
        my %rec;
        if ( @rec{@fields} = /$regex/ ) { push @recs, \%rec }
    }

    return \@recs;
}

sub speed_trap
{
    my $text = shift;

    my $regex = qr/
        ^\ +
        ($pos_re)\ +
        ($no_re)\ +
        ($driver_re)\ +
        ($kph_re)\ +
        ($tod_re)\s+
    /x;

    my @recs;
    my @fields = qw( pos no driver kph time_of_day);

    while (<$text>) {
        my %hash;
        if ( @hash{@fields} = /$regex/ ) { push @recs, \%hash }
    }

    return \@recs;
}

sub maximum_speeds
{
    my $text = shift;

    my $regex  = qr/\G($driver_re) +($kph_re)\s+/;
    my $num_re = qr/ ($no_re) /;

    my ( $line, $driver, $kph, $time, $pos, $no, $speedtrap, @recs );

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

    my $sectortime_re = '\d\d\.\d\d\d';
    my $regex         = qr/\G($driver_re) +($sectortime_re)\s+/;
    my $num_re        = qr/ ($no_re) /;

    my ( $line, $driver, $time, $pos, $no, $sector, @recs );

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

    connection_factory($db_source, DB_PWD, DB_USER);
}

sub connection_factory
{
    my ($db_source, $db_pwd, $db_user) = @_;
    my $dbh;

    sub {
        unless ( $dbh and $dbh->ping ) {
            $dbh = DBI->connect( $db_source, $db_user, $db_pwd )
                or die $DBI::errstr;
            $dbh->{AutoCommit} = 0;
            $dbh->{RaiseError} = 1;
            $dbh->do("PRAGMA foreign_keys = ON");
        }
        $dbh;
    }
}

sub db_insert_array
{
    my ( $race_id, $table, $array_ref ) = @_;

    my $dbh = $db_session->();
    my $tuples;
    my @tuple_status;

    if ( scalar @$array_ref == 0 ) {
        warn "No records to insert for table $table\n";
        return;
    }

    eval {
        my @keys = keys %{ $$array_ref[0] };

        # create insert sql statement with placeholders, using hash keys as
        # field names
        my $stmt = sprintf "INSERT INTO %s (race_id, %s) VALUES (?, %s)",
          $table, join( ', ', @keys ), join( ', ', ('?') x scalar @keys );

        my $sth = $dbh->prepare($stmt);

        my $tuple_fetch = sub {
            return unless my $href = pop @{$array_ref};
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
        print Dumper \@tuple_status;
        warn "Transaction aborted because: $@";
        eval { $dbh->rollback };
    }
    else {
        print "$tuples record(s) added to table $table\n" unless $quiet;
    }

    return $tuples;
}

sub get_doc_links
{
    my ( $base, $page ) = @_;
    my $url = $base . $page;
    my $content;

    unless ( $content = get $url ) {
        die "Unable to get $url";
    }

    my $parser = HTML::LinkExtor->new;
    $parser->parse($content);
    my @links = $parser->links;
    my @docs  = ();

    foreach my $linkarray (@links) {
        my ( $tag, %attr ) = @$linkarray;
        next unless $tag eq 'a';
        next unless $attr{href} =~ /(^.*\.pdf$)/;
        push @docs, $1;
    }

    return \@docs;
}

sub show_calendar
{
    my $year = shift;

    if ( defined $year ) { $year = 1900 + (localtime)[5] unless $year }

    my $sql = <<'SQL';
SELECT rd, date, gp, start, id
FROM calendar
WHERE season=?
ORDER BY rd
SQL

    my $dbh = $db_session->();
    my $recs = $dbh->selectall_arrayref( $sql, { Slice => {} }, ($year) );

    my ( $rd, $date, $gp, $start, $id );

    format CALENDAR_TOP =

 rnd     date     grand prix        start  id
-----------------------------------------------
.

    format CALENDAR =
@||||@||||||||||||@<<<<<<<<<<<<<<<@||||||||@<<<
$rd, $date,      $gp,             $start,  $id
.

    $^ = 'CALENDAR_TOP';
    $~ = 'CALENDAR';

    for my $rec (@$recs) {
        $rd    = $rec->{rd};
        $date  = $rec->{date};
        $gp    = $rec->{gp};
        $start = $rec->{start};
        $id    = $rec->{id};
        write;
    }
}

sub show_exports
{
    my $href = shift;
    my ( $value, $desc );

    format EXPORTS_TOP =
Exports:
 value                 description
--------------------- ---------------------------------------------------------
.

    format EXPORTS=
 @<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
 $value,               $desc 
.

    use FileHandle;
    STDOUT->format_name('EXPORTS');
    STDOUT->format_top_name('EXPORTS_TOP');

    for my $k (
        map {
            my $re = qr/$_/;
            sort grep /$re/, keys %$href
        } qw( ^s ^q ^r )
      )
    {
        $value = $k;
        $desc  = $$href{$k}{desc};
        write;
    }
}

sub get_export_map
{
    my $export_href = {
        'race-laps-xtab' => {
            src  => 'race_lap_xtab',
            desc => 'Cross-tab of lap times by lap/car in \'hh:mm:ss.fff\'',
        },
        'race-laps' => {
            src  => 'race_lap_hms',
            desc => 'Race lap times in \'hh:mm:ss.fff\' format',
        },
        'race-drivers' => {
            src   => 'race_driver',
            desc  => 'Starting grid drivers',
            order => 'race_id, no',
        },
        'qualifying-laps' => {
            src  => 'qualifying_lap_hms',
            desc => 'Qualifying lap times in \'hh:mm:ss.fff\' format',
        },
        'qualifying-drivers' => {
            src   => 'qualifying_driver',
            desc  => 'Qualifying  drivers',
            order => 'race_id, no',
        },
        'session1-drivers' => {
            src   => 'practice_1_driver',
            desc  => 'Practice session 1 drivers',
            order => 'race_id, no',
        },
        'session1-laps' => {
            src   => 'practice_1_lap_hms',
            desc  => 'Practice session 1 lap times',
            order => 'race_id, no',
        },
        'session2-drivers' => {
            src   => 'practice_2_driver',
            desc  => 'Practice session 2 drivers',
            order => 'race_id, no',
        },
        'session2-laps' => {
            src   => 'practice_2_lap_hms',
            desc  => 'Practice session 2 lap times',
            order => 'race_id, no',
        },
        'session3-drivers' => {
            src   => 'practice_3_driver',
            desc  => 'Practice session 3 drivers',
            order => 'race_id, no',
        },
        'session3-laps' => {
            src   => 'practice_3_lap_hms',
            desc  => 'Practice session 3 lap times',
            order => 'race_id, no',
        },

    };

    return $export_href;
}

sub get_pdf_map
{
    unless ($pdf_href) {
        $pdf_href = {

            # Practice
            'session1-classification' => {
                parser => \&practice_session_classification,
                table  => 'practice_1_classification',
            },
            'session1-times' => {
                parser   => \&time_sheet,
                table    => 'practice_1_lap_time',
                fk_table => 'practice_1_driver',
            },
            'session2-classification' => {
                parser => \&practice_session_classification,
                table  => 'practice_2_classification',
            },
            'session2-times' => {
                parser   => \&time_sheet,
                table    => 'practice_2_lap_time',
                fk_table => 'practice_2_driver',
            },
            'session3-classification' => {
                parser => \&practice_session_classification,
                table  => 'practice_3_classification',
            },
            'session3-times' => {
                parser   => \&time_sheet,
                table    => 'practice_3_lap_time',
                fk_table => 'practice_3_driver',
            },

            # Qualifying
            'qualifying-sectors' => {
                parser => \&best_sector_times,
                table  => 'qualifying_best_sector_time',
            },
            'qualifying-speeds' => {
                parser => \&maximum_speeds,
                table  => 'qualifying_maximum_speed',
            },
            'qualifying-times' => {
                parser   => \&time_sheet,
                table    => 'qualifying_lap_time',
                fk_table => 'qualifying_driver',
            },
            'qualifying-trap' => {
                parser => \&speed_trap,
                table  => 'qualifying_speed_trap',
            },
            'qualifying-classification' => {
                parser => \&qualifying_classification,
                table  => 'qualifying_classification',
            },

            # Race
            'race-analysis' => {
                parser   => \&time_sheet,
                table    => 'race_lap_analysis',
                fk_table => 'race_driver',
            },
            'race-grid' => {
                parser => \&provisional_starting_grid,
                table  => 'race_grid',
            },
            'race-history' => {
                parser => \&race_history_chart,
                table  => 'race_history',
            },
            'race-laps' => {
                parser => \&race_fastest_laps,
                table  => 'race_fastest_lap',
            },
            'race-sectors' => {
                parser => \&best_sector_times,
                table  => 'race_best_sector_time',
            },
            'race-speeds' => {
                parser => \&maximum_speeds,
                table  => 'race_maximum_speed',
            },
            'race-summary' => {
                parser => \&race_pit_stop_summary,
                table  => 'race_pit_stop_summary',
            },
            'race-trap' => {
                parser => \&speed_trap,
                table  => 'race_speed_trap',
            },

            'race-classification' => {
                parser => \&race_classification2,
                table  => 'race_classification',
            },
            
            # TODO
            # 'race-chart'
        };
    }

    return $pdf_href;
}

# POD

=head1 NAME

f1.pl - Download timing PDFs and update database

=head1 SYNOPSIS

 Options:
    --help                  brief help message
    --man                   full documentation
    -t, --timing[=<value>]  download timing PDFs from FIA web site
    -u, --update[=<pdf>]    parse PDFs and update database     
    -c, --calendar[=<year>] show race calendar for year
    -q, --quiet             no messages
    -e, --export[=<value>]  export data in CSV format or list options
    -r, --race-id=<value>   filter export data bay race id
    --export-opts=<value>   override default export options
    --race-id=<value>       filter export data using race id
    --docs-dir=<path>       use path as source for PDF files
    --db-path=<path>        use path as source for database
    --version               print script version

    
=head1 DESCRIPTION

B<f1.pl> will download the latest FIA timing PDF files, extract the data from
the documents, parse it and add the records to a database. The data can also
be exported in CSV format for further analysis.

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Print the manual page and exits.

=item B<-t, --timing[=E<lt>valueE<gt>]>

Download latest timing PDF files from the FIA web site.
Recognized optional values are:

=over 4

=item p1, p2, or p3   - individual practice sessions

=item p               - all practice sessions

=item q               - qualifying

=item r or sun        - race

=item thu or fri      - practice sessions 1 and 2

=item sat             - practice session 3 and qualifying

=item

=item Examples:

=item --timing=thu - download Monaco practice session 1 & 2

=item --timing=p3  - download practice session 3

=item --timing     - download all available timing PDFs

=item -t r         - download all race timing PDFs

=back

=item

=item B<-u, --update[=E<lt>valueE<gt>]>

Parse PDF(s) and update database. The value is can be the three letter race
id as used by the FIA e.g., 'gbr' for the British Grand Prix, the filename of
an individual PDF without the file suffix e.g., chn-race-analysis or the id
with one of the session codes as documented in the I<timing> option. For a full
list of the available options use the option with a value. The FIA race codes 
can be obtained using the I<calendar> option, below.

The file path for the required PDF is defined in the script constant
I<DOCS_DIR>, to which the three letter race code is added e.g, if DOCS_DIR is
set to F</home/username/F1> and the required timing document is mco-race-trap
the full file path will be F</home/username/F1/mco/mco-race-trap.pdf>.

The search path can be changed on the command line with the docs-dir
option.

=over 4

=item Examples:

=item --update=gbr		- all British Grand Prix PDFs

=item -u chn-race-analysis	- single named PDF

=item -update=can-q		- all Canadian GP qualifying session PDFs

=item -u			- list all available options

=back

=item B<-c, --calendar[=E<lt>yearE<gt>]>

Display race calendar for current year, or if the optional year is provided,
for that year.

=item B<-q, --quiet>

No messages to confirm the PDF file downloaded of the number of records added
to each database table.

=item B<-e, --export[=E<lt>valueE<gt>]>

Export data in CSV format. Redirect to a file for loading into a spreadsheet or
another database. The <value> is the source view or table; omit the value to
display a list of possible sources.

=over 4

=item Examples:

=item --export=calendar                 - print calendar to stdout

=item --export=race-lap-xtab > laps.csv - export lap times to file

=back

=item

=item B<-r, --race-id=E<lt>valueE<gt>>

Filter the data exports by race using a race id.

=item B<--export-opts=E<lt>valueE<gt>>

Override the default export format (CSV with headers).

=over 4

=item Examples:

=item --export-opts='-html -header'   - HTML table with headers

=item --export-opts=-list             - list with '|' delimiter

=back

See the SQLite help for more formats and options.

=item B<-d, --docs-dir=E<lt>pathE<gt>>

Search <path> for timing PDFs. Over-rides the path contained in the script
I<DOCS_DIR> constant and the environment variable I<F1_TIMING_DOCS_DIR>.

=item B<--db-path=E<lt>pathE<gt>>

File path of SQLite database. Overrides the path contained in the script
I<DB_PATH> constant and the I<F1_TIMING_DB_PATH> environment variable.

=item B<--version>

Show script version.

=back

=head1 ENVIRONMENT VARIABLES

The following environment variables are recognized, and take precedence over
the equivalent script constant.

=over 8

=item I<F1_TIMING_DOCS_DIR>

Source directory searched for FIA PDF timing files.

=item I<F1_TIMING_DB_PATH>

Path to SQLite database file.

=back

=head1 BUGS

Some documents cannot be converted to text by pdftotext. These are typically
the facsimile type documents such as the provisional grid and qualifying
classification which are signed by the stewards.

The regular expressions used to parse the text may fail when there are unusual
race events or anything else that changes the format of the PDFs.

Because of the way that SQLite stores time data there may be rounding errors
when performing time calculations in SQL queries e.g., summing lap times.

=head1 AUTHOR

Nigel Garside, nigel.garside@gmail.com

=cut
