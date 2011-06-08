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

# config variables
use constant DOCS_DIR    => "$ENV{HOME}/Documents/F1/";
use constant CONVERTER   => 'pdftotext';
use constant CONVERT_OPT => '-layout';
use constant EXPORTER    => 'sqlite3';
use constant EXPORT_OPT  => '-list -separator , -header';
use constant TIMING_BASE => 'http://fia.com/en-GB/mediacentre/f1_media/Pages/';
use constant TIMING_PAGE => 'timing.aspx';

# old FIA web page
#  'http://fialive.fiacommunications.com/en-GB/mediacentre/f1_media/Pages/';

# database variables
use constant DB_PATH => "$ENV{HOME}/Documents/F1/db/f1_timing.db3";
use constant DB_PWD  => q{};
use constant DB_USER => q{};

use constant VERSION => '20110612';

# database handle
my $dbh = undef;

# comand line option variables
my $timing     = undef;
my $update     = undef;
my $export     = undef;
my $export_opt = undef;
my $race_id    = undef;
my $calendar   = undef;
my $docs_dir   = undef;
my $verbose    = 0;
my $db_path    = undef;
my $help       = 0;
my $man        = 0;
my $version    = 0;

# test/debug
my $debug = 0;
my $test  = 0;

Getopt::Long::Configure qw( no_auto_abbrev bundling);
GetOptions(
    'timing:s'         => \$timing,
    't:s'              => \$timing,
    'update:s'         => \$update,
    'u:s'              => \$update,
    'export=s'         => \$export,
    'e=s'              => \$export,
    'export-options=s' => \$export_opt,
    'race-id=s'        => \$race_id,
    'c:i'              => \$calendar,
    'calendar:i'       => \$calendar,
    'db-path=s'        => \$db_path,
    'docs-dir=s'       => \$docs_dir,
    'help'             => \$help,
    'man'              => \$man,
    'version'          => \$version,
    'test'             => \$test,
    'debug'            => \$debug,
) or pod2usage(2);

# shared regexs
my $driver_re  = q<[A-Z]\. [A-Z '-]+?>;
my $time_re    = '\d+:\d\d\.\d\d\d';
my $kph_re     = '\d\d\d\.\d{1,3}';
my $entrant_re = '[A-z0-9& -]+';
my $pos_re     = '\d{1,2}';
my $no_re      = $pos_re;
my $lap_re     = '\d{1,2}';
my $tod_re     = '\d\d:\d\d:\d\d';

# PDF mappings
my $pdf_href = undef;

# Process command-line arguments
#
# use default optiona if none specified
unless ( $export_opt ) { $export_opt = EXPORT_OPT }

if    ($help)     { pod2usage(2) }
elsif ($man)      { pod2usage( -verbose => 2 ) }
elsif ($timing)   { get_timing() }
elsif (defined $update)   { update_db($update) }
elsif (defined $calendar) { show_calendar($calendar) }
elsif ($export)   { export( $export, $race_id ) }
elsif ($version)  { print "$0 v@{[VERSION]}\n" }
elsif ($test) {
    show_exports();
}

# download timing PDFs from FIA web site
sub get_timing
{
    my $check_exists = 1;
    my $race;
    my $get_docs;
    my %args;

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
        %args = (
            p1  => qr/session1/,
            p2  => qr/session2/,
            p3  => qr/session3/,
            p   => qr/session[123]/,
            q   => qr/qualifying/,
            r   => qr/race/,
            fri => qr/session[12]/,
            sat => qr/session3|qualifying/,
        );
        $args{thu} = $args{fri};
        $args{sun} = $args{r};

        my $arg = lc $timing;
        defined( my $re = $args{$arg} )
          or die "$timing timing option not recognized\n";

        $get_docs = [ grep /$re/, @$docs ];
    }

    print Dumper $get_docs if $debug;

    my $src_dir  = get_docs_dir();
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
            print "Overwrite? ([y]es/[n]o/[a]ll/[c]ancel)\n";
            ReadMode 'cbreak';
            my $answer = lc ReadKey(0);
            ReadMode 'normal';

            while ( index( 'ynac', $answer ) < 0 ) {
                print "\nPlease enter [y]es/[n]o/[a]ll/[c]ancel)?\n";
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
            print "Downloaded $pdf.\n";
        }
        else {
            warn "Error downloading $pdf. (Error code: $rc)\n";
        }
    }
}

sub get_docs_dir
{
    if ( $docs_dir ) { return $docs_dir }
    elsif ( my $env = $ENV{F1_TIMING_DOCS_DIR} ) { return $env }
    else                                         { return DOCS_DIR }
}

sub update_db
{
    my $arg = shift;

    my ( $race, $timesheet, $pdf_ref );
    my $pdf_map = get_pdf_map();

    #print $arg, "\n";

    my $len = length $arg;

    if ($len == 0) {
        my @keys = sort keys %$pdf_map;
        print "$0 update options:-\n\n";
        print "Enter the three letter race id or choose from the following:\n";
        print "\n\t", (join "\n\t", grep /^s/ , @keys);
        print "\n\t", (join "\n\t", grep /^q/ , @keys);
        print "\n\t", (join "\n\t", grep /^r/ , @keys), "\n";;
        return;
    }
    elsif ($len == 3) {
        $race    = $arg;
        $pdf_ref = $pdf_map;
    }
    elsif ( $len > 3 ) {
        ( $race, $timesheet ) = $arg =~ /^([a-z]{3})-(.+)$/;
        $pdf_ref = { $timesheet => $pdf_map->{$timesheet} }
          or die "Timing document $arg not recognized\n";
    }
    else  {
      die "Please provide an update argument of at least 3 characters\n";
    }

    my $race_dir = catdir( get_docs_dir(), $race );
    my $year = 1900 + (localtime)[5];
    my $race_id = "$race-$year";

    for my $key ( keys %$pdf_ref ) {
        my $src = catfile( $race_dir, "$race-$key.pdf" );
        -e $src or die "Error: file $src does not exist\n";

        # use two arg open method to get shell redirection to stdout
        my $pipe_cmd = qq<"@{[CONVERTER]}" @{[CONVERT_OPT]} "$src" - |>;

        open my $text, $pipe_cmd
          or die 'unable to open ' . CONVERTER . ": $!";

        my $href = $pdf_ref->{$key};
        my ( $recs, $fk_recs ) = $href->{parser}($text);

        if ( $fk_recs ) {
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

    my $db  = get_db_source();
    my $map = get_export_map();
    my $sql;

    print Dumper $map if $debug;

    my $src = $$map{$value}{src}
        or die "$value export not found";

    if ( $race_id ) {
        $sql = "SELECT * FROM $src WHERE race_id='$race_id'";
    }
    else {
        $sql = "SELECT * FROM $src";
    }

    if (my $order = $$map{$value}{order}) { $sql .= " ORDER BY $order" }
    print "$sql\n" if $debug;

    my $pipe_cmd = qq <"> . EXPORTER . qq <" $export_opt "$db">;

    open my $exporter, "|-", $pipe_cmd
      or die "Unable to open " . EXPORTER . ": $!";

    print $exporter "$sql;";

    close $exporter
      or die "Error closing " . EXPORTER . ": $!";
}

sub race_history_chart
{
    my $text = shift;

    my $header_re = qr/(?:LAP )(\d{1,2})(?:    |\n)/;

    my $laptime_re =
qr/(?:(?!\d{1,2} )(\d*)(\d\d\d\.\d\d\d) +(\d:\d\d\.\d\d\d))|(\d{1,2}) +(P)?(?:IT)?(?:\d [LAPS]{3,4}|\d{1,3}\.\d{3}| +)? +(\d:\d\d\.\d\d\d)/;
    my ( @col_pos, $width, $prev_col, $len, $idx, $line, @recs );
    my @fields = qw(lap no  pit time);
    my @drivers;
    my $laptime;

  HEADER:
    while (<$text>) {
        if ( my @laps = /$header_re/g ) {

            print Dumper \@laps if $debug;
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
                        while (
                            substr( $_, $prev_col, $width ) =~ /$laptime_re/g )
                        {
                            my ( $n, $p, $t );
                            if ( $1 ) {
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

    my $left  = qr/($pos_re) +($no_re) +($driver_re)\**(?: {2,}|\n)($time_re)?/;
    my $right = qr/($no_re) +($driver_re)\** +($time_re)? +($pos_re)/;
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
    my $regex = qr/($no_re) +($driver_re) {2,}($entrant_re?) +($lap_re) +/;
    $regex .= qr/($tod_re) +($stop_re) +($duration_re) +($totaltime_re)/;

    my @recs;

    while (<$text>) {
        my %hash;
        push @recs, \%hash if ( @hash{@fields} = /$regex/ );
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

    my $header_re  = qr/($no_re)\s+($driver_re)(?: {2,}|\n)/;
    my $laptime_re = qr/($lap_re) *(P)? +($tod_re|$time_re)\s?/;
    my $tod_re     = qr/$tod_re/;
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
                            my ( $l, $p, $t ) = ( $1, $2, $3 );
                            $t = "00:0$t" unless $t =~ /$tod_re/;
                            my %temp;
                            @temp{@fields} =
                              ( $nos[$idx]->{'no'}, $l, $p, $t );
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
    my $nat_re = '[A-Z]{3}';
    my $gap_re = '\d{1,2}\.\d\d\d';

    my $regex =
      qr/($pos_re) +($no_re) +($driver_re) +($nat_re) +($entrant_re?) +/;
    $regex .= qr/($time_re)? *($lap_re) *($gap_re)? *($kph_re)? *($tod_re)?\s+/;
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
    my $regex      = qr/($pos_re)? +($no_re)(?: +[A-Z].*?)/;
    $regex .= qr/($time_re) *($lap_re)? *($percent_re)? *($tod_re)?\s*/;
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

    print Dumper scalar @recs if $debug;
    foreach (@recs) {
        print $$_{no}, "\n";
    }
    return \@recs;
}

sub speed_trap
{
    my $text = shift;

    my $regex =
      qr/^ +($pos_re) +($no_re) +($driver_re) +($kph_re) +($tod_re)\s+/;

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

    my $sectortime_re  = '\d\d\.\d\d\d';
    my $regex  = qr/\G($driver_re) +($sectortime_re)\s+/;
    my $num_re = qr/ ($no_re) /;

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

    if ( $db_path ) {
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
    unless ( $dbh and $dbh->ping ) {
        my $db_source = 'dbi:SQLite:dbname=' . get_db_source;
        $dbh = DBI->connect( $db_source, DB_USER, DB_PWD )
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

    my $dbh = db_connect;
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
        print Dumper \@tuple_status;
        warn "Transaction aborted because: $@";
        eval { $dbh->rollback };
    }
    else {
        print "$tuples record(s) added to table $table\n";
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
SELECT round, date, grand_prix, start, id
FROM calendar
WHERE season=?
ORDER BY round
SQL

    my $dbh = db_connect;
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

    foreach my $rec (@$recs) {
        $rd    = $rec->{round};
        $date  = $rec->{date};
        $gp    = $rec->{grand_prix};
        $start = $rec->{start};
        $id    = $rec->{id};
        write;
    }
}

sub show_exports
{
    my $href = get_export_map();
    my ( $value, $param, $field, $desc );

format EXPORTS_TOP =

 value          param? field         description
--------------- ------ ------------- -----------------------------------------
.

format EXPORTS=
 @<<<<<<<<<<<<<@|||||||@<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
 $value,       $param, $field,       $desc    
.

    use FileHandle;
    STDOUT->format_name('EXPORTS');
    STDOUT->format_top_name('EXPORTS_TOP');

    for my $k ( keys %$href ) {
        $value = $k;
        ( $param, $field, $desc ) = @{ $href->{$k} }{qw(param pfield desc)};
        write;
    }
}

sub get_export_map
{
    my $export_href = {
        'race-laps-xtab' => {
            src    => 'race_lap_xtab',
            desc   => 'Desc 1',
        },
        'race-laps' => {
            src    => 'race_lap_hms',
            desc   => 'Desc 2',
        },
        'race-drivers' => {
            src    => 'race_driver',
            desc   => 'Starting grid drivers',
            order => 'race_id, no',
        },
        'qualifying-laps' => {
            src    => 'qualifying_lap_hms',
            desc   => 'Qualifying lap times in hh:mm:ss.sss format',
        },
        'qualifying-drivers' => {
            src    => 'qualifying_driver',
            desc   => 'Qualifying  drivers',
            order => 'race_id, no',
        },
        'session1-drivers' => {
            src    => 'practice_1_driver',
            desc   => 'Practice session 1 drivers',
            order => 'race_id, no',
        },
        'session1-laps' => {
            src    => 'practice_1_lap_hms',
            desc   => 'Practice session 1 lap times',
            order => 'race_id, no',
        },
        'session2-drivers' => {
            src    => 'practice_2_driver',
            desc   => 'Practice session 2 drivers',
            order => 'race_id, no',
        },
        'session2-laps' => {
            src    => 'practice_2_lap_hms',
            desc   => 'Practice session 2 lap times',
            order => 'race_id, no',
        },
        'session3-drivers' => {
            src    => 'practice_3_driver',
            desc   => 'Practice session 3 drivers',
            order => 'race_id, no',
        },
        'session3-laps' => {
            src    => 'practice_3_lap_hms',
            desc   => 'Practice session 3 lap times',
            order => 'race_id, no',
        },

    };

    return $export_href;
}

sub get_pdf_map
{
    unless ( $pdf_href ) {
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

            # TODO
            # OTHERS
            # 'race-chart'
            # 'race-classification'
        };
    }

    return $pdf_href;
}

# POD

=head1 NAME

f1.pl - Download timing PDFs and update database

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
    --help                  brief help message
    --man                   full documentation
    -t, --timing[=<value>]  download timing PDFs from FIA web site
    -u, --update[=<pdf>]    parse PDFs and update database     
    -c, --calendar[=<year>] show race calendar for year
    -e, --export[=<value>]  export data in CSV format or list options
    --race-id=<value>       filter export data using race id
    --docs-dir=<path>       use path as source for PDF files

    
=head1 DESCRIPTION

B<f1.pl> will read the given input file(s) and do something
useful with the contents thereof.

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

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

=back

Examples:

=over 4

=item --timing=thu - download Monaco practice session 1 & 2

=item --timing=p3  - download practice session 3

=item --timing     - download all available timing PDFs

=item -t r         - download all race timing PDFs

=back

=item

=item B<-u, --update=E<lt>valueE<gt>>

Parse PDF(s) and update database. The required value is either the three
letter abbreviation as used by the FIA for each race e.g., 'gbr' for the
British Grand Prix, or the filename of an individual PDF without the file
suffix e.g., chn-race-analysis. The race codes can be obtained using the
I<calendar> option, below.

The file path for the required PDF is defined in the script constant
I<DOCS_DIR>, to which the current year is added e.g, if DOCS_DIR is set to
F</home/username/F1> and the required timing document is mco-race-trap the
full file path will be F</home/username/F1/2011/mco-race-trap.pdf>.

The search path can be changed on the command line with the docs-dir
option, below.

=item B<-d, --docs-dir=E<lt>pathE<gt>>

Search <path> for timing PDFs. Over-rides the path contained in the script
I<DOCS_DIR> constant and the environment variable I<F1_TIMING_DOCS_DIR>.

=item B<-c, --calendar[=E<lt>yearE<gt>]>

Display race calendar for current year, or if the optional year is provided,
for that year.

=item B<--db-path=E<lt>pathE<gt>>

File path of SQLite database. Over-rides the path contained in the script
I<DB_PATH> constant and the I<F1_TIMING_DB_PATH> environment variable.

=item B<-e, --export[=E<lt>valueE<gt>>

Export data in CSV format. Redirect to a file for loading into a spreadsheet or
another database. The <value> is the source view or table; omit the value to
display a list of possible sources.

=over 4

=item Examples:

=item --export=calendar                 - print calendar to stdout

=item --export=race-lap-xtab > laps.csv - export lap times to CSV file

=back

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
