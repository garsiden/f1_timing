#! /usr/bin/env perl

use YAML::XS qw(LoadFile);
use File::Spec;
use File::Basename;
use Data::Dumper;
use Const::Fast;

use strict;
use warnings;
use 5.012;

# config constants
const my $SEASON    => '2013';
const my $DOCS_DIR  => "$ENV{HOME}/Documents/F1";
const my $GRAPH_DIR => "$DOCS_DIR/$SEASON/Graphs";
const my $YAML      => 'f1graphs.yaml';

my $path = File::Spec->rel2abs(__FILE__);
my $yaml = dirname($path) . "/$YAML";

say $yaml;

my $hash = LoadFile $yaml;
mergekeys($hash);
print Dumper $hash;

print Dumper $hash->{race_lap_times_fuel_adj};

sub mergekeys
{
    return _mergekeys( $_[0], [] );
}

# http://www.perlmonks.org/?node_id=813443
sub _mergekeys
{
    my $ref          = shift;
    my $resolveStack = shift;
    my $reftype      = ref $ref;

    # If this hash or array is already on the resolution stack, then
    # somewhere, a child data structure is trying to inherit from one of its
    # parents, and hence by extension trying to inherit itself.
    if ( $reftype =~ /HASH|ARRAY/ and ( grep $_ == $ref, @$resolveStack ) > 0 )
    {
        # Halt and catch fire, or store the cyclic reference and not
        # process it further. Not complaining seems to be the behaviour of
        # Ruby's YAML parser, so let's go for that.

        # die "Cyclic inheritance detected: "
        #   . ($ref)
        #   . " is already on the resolution stack!\n"
        #   . "Dump of cyclic data structure (may have inheritance already "
        #   . "partially resolved):\n" . Dumper($ref);
        return $ref;
    }

    if ( ref($ref) eq 'HASH' ) {

        push @$resolveStack, $ref;

        if ( exists $ref->{'<<'} ) {

            # can be either a single href, or an array of hrefs
            my $inherits = $ref->{'<<'};

            # catch edge cases that YAML::XS won't catch, like "<<: &foo"
            die "Undefined value for merge key '<<' in " . Dumper($ref)
              unless defined $inherits;

            die "Merge key does not support merging non-hashmaps"
              unless ref($inherits) =~ /HASH|ARRAY/;

            # normalize for further processing
            $inherits = [$inherits] if ref($inherits) eq 'HASH';

          # For each of the hashes/arrays we're inheriting, have them
          # resolve their inheritance first before applying them onto ourselves.
          # Also, remove the '<<' reference only afterwards, since by
          # recursion these will have already been removed from our inheritees,
          # and this also allows us to show the cyclic reference by dumping
          # out the structure when we detect one.
            foreach my $inherit (@$inherits) {
                $inherit = _mergekeys( $inherit, $resolveStack );
                %$ref = ( %$inherit, %$ref );
            }
            delete $ref->{'<<'};
        }

        _mergekeys( $_, $resolveStack ) for ( values %$ref );
        die "Fatal error: imbalanced recursion stack in _mergekeys. "
          . "This likely implies a programming error and/or a YAML file from hell."
          unless pop(@$resolveStack) eq $ref;
    }
    elsif ( ref($ref) eq 'ARRAY' ) {
        push @$resolveStack, $ref;
        _mergekeys( $_, $resolveStack ) for (@$ref);
        die "Fatal error: imbalanced recursion stack in _mergekeys. "
          . "This likely implies a programming error and/or a YAML file from hell."
          unless pop(@$resolveStack) eq $ref;
    }

    return $ref;
}

