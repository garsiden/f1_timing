#! /usr/bin/env perl

use DBI;
use LWP::Simple;
use Data::Dumper;
use XML::LibXML;

use strict;
use warnings;

# config constants
use constant SEASON      => '2013';
use constant DOCS_DIR    => "$ENV{HOME}/Documents/F1/";
use constant ERGAST      => 'http://ergast.com/api/f1/';

my $race_xml = "$ENV{HOME}/Projects/git/f1_timing/data/ergast_2013.xml";

my $parser = XML::LibXML->new();
my $dom = $parser->parse_file($race_xml);
my @races = $dom->getElementsByTagName("Race");
  my $xpc = XML::LibXML::XPathContext->new;
  $xpc->registerNs('x','http://ergast.com/mrd/1.3'); 

foreach my $r (@races) {
    my @attr = $r->attributes();
    foreach my $a (@attr) {
        print $a->nodeName, "\t", $a->nodeValue, "\n";
    }
    print $r->firstChild->data,"\n";
    #print $xpc->findvalue('/x:RaceName',$r);
    print $r->nodePath();
    #print Dumper ($r->findvalue('/:RaceName'));
    #print Dumper $attr;
    #print $r->nodeName, "\n";
}

#print Dumper $data;
