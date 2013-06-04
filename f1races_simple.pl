#! /usr/bin/env perl

use DBI;
use LWP::Simple;
use Data::Dumper;
use XML::Simple;

use strict;
use warnings;

# config constants
use constant SEASON      => '2013';
use constant DOCS_DIR    => "$ENV{HOME}/Documents/F1/";
use constant ERGAST      => 'http://ergast.com/api/f1/';

my $race_xml = "$ENV{HOME}/Projects/git/f1_timing/data/ergast_2013.xml";
my $xml = new XML::Simple;

my $data = $xml->XMLin($race_xml);

print Dumper $data;
