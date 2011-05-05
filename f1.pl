#! /usr/bin/env perl
use DBI;
use LWP::Simple;
use HTML::LinkExtor;
use Getopt::Long;
use Data::Dumper;
use YAML qw( );
use Term::ReadKey;

use strict;
use warnings;
no strict 'vars';

# parse FIA F1 timing PDFs

$data_dir = "$ENV{HOME}/Documents/F1/aus/";
$docs_dir = "$ENV{HOME}/Documents/F1/";

#$timing_base =
#  'http://fialive.fiacommunications.com/en-GB/mediacentre/f1_media/Pages/';
$timing_base = 'http://fia.com/en-GB/mediacentre/f1_media/Pages/';
$timing_page = 'timing.aspx';

$quiet   = 1;

use constant PDFTOTEXT => '/usr/local/bin/pdftotext';

$database = q{};
$help     = 0;
$man      = 0;
$update   = undef;
$test     = 0;
$timing   = undef;

Getopt::Long::Configure qw( no_auto_abbrev bundling);
GetOptions(
    'help'       => \$help,
    'man'        => \$man,
    'database=s' => \$database,
    'update=s'   => \$update,
    'u=s'        => \$update,
    'timing:s'   => \$timing,
    't'          => \$timing,
    'test'       => \$test,
);

# shared regexs
$driver_re     = q#[A-Z]\. [A-Z '-]+?#;
#$name_re       = $driver_re;
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

# Process command-line arguments
if ( defined $pause ) { $pause = 1 unless $pause; }

if ( defined $timing ) {
    get_timing();
}

# download timing PDFs from FIA website
sub get_timing
{
    my $dload        = q{};
    my $check_exists = 1;

    # get list of latest pdfs
    my $docs = get_doc_links( $timing_base, $timing_page );

    if ( scalar @$docs == 0 ) {
        print "No timing currently available.\n";
    }
    else {
        $$docs[0] =~ /([a-z123-]+.pdf$)/;    # get race prefix of first PDF
        my $race = substr $1, 0, 3;
        $dload = 1;
    }

    # if race prefix given check against retrieved list
    if ( length $timing ) { $dload = $timing eq $race; }

    if ($dload) {
        my $race_dir = $docs_dir . $race;

        unless ( -d $race_dir ) {
            mkdir $race_dir
              or die "Unable to create directory $race_dir: $! $?\n";
            $check_exists = 0;
        }

        foreach (@$docs) {
            ( my $pdf ) = /([a-z123-]+.pdf$)/;
            my $dest = $race_dir . '/' . $pdf;
            if ( $check_exists and -f $dest ) {
                print "File $dest already exists.\n";
                print "Overwrite? ([y]es/[n]o/[a]ll/[c]ancel) ";
                ReadMode 'cbreak';
                my $answer = lc ReadKey(0);
                ReadMode 'normal';

                while ( index( 'ynac', $answer ) < 0 ) {
                    print "\nPlease enter [y]es/[n]o/[a]ll/[c]ancel)? ";
                    ReadMode 'cbreak';
                    $answer = lc ReadKey(0);
                    ReadMode 'normal';
                }

                print "\n";
                if    ( $answer eq 'c' ) { exit; }
                elsif ( $answer eq 'n' ) { next; }
                elsif ( $answer eq 'a' ) { $check_exists = 0; }
            }
            my $src = $timing_base . $_;
            if ( ( my $rc = getstore( $src, $dest ) ) == RC_OK ) {
                print "Downloaded $pdf.\n";
            }
            else {
                warn "Error downloading $pdf. (Error code: $rc)\n";
            }
        }
    }
}

sub yaml_hash
{
    no strict 'refs';
    print 'Running test...', "\n";
    my $pdf = $data_dir . 'session1-classification';

    open my $text, "PDFTOTEXT -layout $pdf.pdf - |"
      or die "unable to open PDFTOTEXT: $!";
    $parser = 'practice_session_classification';
    $recs   = &$parser($text);

    close $text
      or die "bad PDFTOTEXT: $! $?";

    my $data = do { local $/ = undef; <DATA> };
    my $hashref = YAML::Load($data);
    print Dumper $hashref;
}


# map PDFs to parsing sub-routines and database tables
%pdf = (

    # Practice
    'session1-classification' => {
        parser => \&practice_session_classification,
        table  => 'practice_1_classification',
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
        parser => \&time_sheet,
        table  => 'qualifying_lap_time',
    },
    'qualifying-trap' => {
        parser => \&speed_trap,
        table  => 'qualifying_speed_trap',
    },

    # Race
    'race-analysis' => {
        parser => \&time_sheet,
        table  => 'race_lap_analysis',
    },
    'race-grid' => {
        parser => \&provisional_starting_grid,
        table  => 'race_grid',
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
    #'qualifying-classification' => \&qualifying_session_classification,
    #
    #'session1-times' => first_practice_session_lap_times,
    #'session2-classification' => second_practice_session_classification,
    #'session2-times' => second_practice_session_lap_times,
    #'session2-classification' => third_practice_session_classification,
    #'session3-times' => third_practice_session_lap_times,
    #
    # OTHERS
    # 'race-chart'
    # 'race-classification'
    # 'race-history'
);

# Update databse from PDFs
if (defined $update) {
    update_db($update);
}

sub update_db
{
    my $arg = shift;

    my ( $race, $timesheet, $pdf_ref );

    ( my $len = length $arg ) >= 3
      or die "Please provide an update argument of at least 3 characters\n";

    if ( $len > 3 ) {
        ( $race, $timesheet ) = $arg =~ /^([a-z]{3})-(.+)$/;
        $pdf_ref = { $timesheet => $pdf{$timesheet} }
          or die "Timing document $arg not recognized\n";
    }
    else {
        $race    = $arg;
        $pdf_ref = \%pdf;
    }

    my $race_dir = $docs_dir . "$race/";
    my $year     = 1900 + (localtime)[5];
    my $race_id  = "$race-$year";

    for my $key ( keys %$pdf_ref ) {
        my $src = $race_dir . "$race-$key";

        # use two arg open method to get shell redirection to stdout
        open my $text, "PDFTOTEXT -layout $src.pdf - |"
          or die "unable to open PDFTOTEXT: $!";

        $href = $pdf_ref->{$key};
        $recs = $href->{parser}($text);
        print Dumper $recs unless $quiet;
        $table = $href->{table};

        db_insert_array( $race_id, $table, $recs );
        close $text
          or die "bad PDFTOTEXT: $! $?";
    }
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
    $regex .= qr/($timeofday_re) +($stop_re) +($duration_re) +($totaltime_re)/;

    my @recs;

    while (<$text>) {
        my %hash;
        next unless ( @hash{@fields} = /$regex/ );
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
                            @temp{@fields} = ( $pos[$idx], $1, $2, $3 );
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

sub get_doc_links
{
    my ( $base, $page ) = @_;
    my $url = $base . $page;
    my $content;

    return [
        '../Documents/mon-this.pdf',
        '../Documents/mon-race-analysis.pdf',
        '../Documents/aus-the-other.pdf'
    ];

    unless ( defined( $content = get $url) ) {
        die "Unable to get $url";
    }

    my $parser = HTML::LinkExtor->new;
    $parser->parse($content);
    my @links = $parser->links;
    my @docs  = ();

    foreach $linkarray (@links) {
        ( $tag, %attr ) = @$linkarray;
        next unless $tag eq 'a';
        next unless $attr{href} =~ /(^.*\.pdf$)/;
        push @docs, $1;
    }

    print join( "\n", @docs ), "\n";

    #return \@docs;
}

__DATA__
qualifying-sectors:
    parser: best_sector_times
    table: qualifying_beast_sector_time
qualifying-speeds:
    parser: maximum_speeds
    table: qualifying_maximum_speed
