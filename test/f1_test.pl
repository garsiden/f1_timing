# output from f1.pl script

use 5.012;

use constant EXPORTER    => 'sqlite3';
use constant EXPORT_OPT  => '-csv -header';
use constant DB_PATH => "$ENV{HOME}/My Documents/F1/2011/db/f1_timing.db";

my $base_dir = "$ENV{HOME}/My Documents/F1/test/output";
my $f1 = "$ENV{HOME}/My Documents/Projects/git/f1_timing/f1.pl";

(my $race_id = shift)
    or die "Please provide a race_id value\n";

my $out_dir = "$base_dir/$race_id";

my @exports = qw (
    session1-drivers
    session1-laps
    session2-drivers
    session2-laps
    session3-drivers
    session3-laps
    qualifying-drivers
    qualifying-laps
    race-drivers
    race-laps
    race-laps-xtab
);

# create race directory
unless (-d "$out_dir") {
    mkdir "$out_dir"
        or die "Unable to create directory $out_dir\n";
}

# output CSV using f1 script
for my $ex ( @exports ) {
    my $cmd =  qq!-e $ex -r $race_id-2011 > "$out_dir/$race_id-$ex.csv"!;
    qx[perl "$f1" $cmd];
}

#export using sqlite3

my @tables = qw(
    practice_1_classification
    practice_2_classification
    practice_3_classification
    qualifying_best_sector_time
    qualifying_classification
    qualifying_maximum_speed
    qualifying_speed_trap
    race_best_sector_time
    race_classification
    race_fastest_lap
    race_grid
    race_history
    race_maximum_speed
    race_pit_stop_summary
    race_speed_trap
    );

  export($race_id, $out_dir, @tables);

sub export
{
    my ($race_id, $out_dir, @tables) = @_;

    my $db = DB_PATH;
    my $export_opts = EXPORT_OPT;

    my $pipe_cmd = qq <"> . EXPORTER . qq <" $export_opts "$db">;

    for my $table (@tables) {
        my $out_file = "$out_dir/$race_id-$table.csv";
        $out_file =~ s/_/-/g;
        my $sql = "SELECT * FROM $table WHERE race_id='$race_id-2011'"; 
        qx!$pipe_cmd "$sql;" > "$out_file"!;
    }

    return;
}
