#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use AirtableGPT::Exporter;
use Getopt::Long;
use Env::Dot;
use Log::Log4perl;
use strict;
use warnings;

sub usage {
    print "Usage: $0\n";
    print "Options:\n";
    print "  --help                        Show this help message\n";
    exit;
}

# Load environment variables from .env file
my $env_file = "$FindBin::Bin/../.env";
Env::Dot->import($env_file);

GetOptions(
    'help' => \&usage,
) or die "Error in command line arguments\n";


# Initialize Log4perl
my $log_conf = "$FindBin::Bin/../conf/log4perl.conf";
Log::Log4perl->init($log_conf);
my $logger = Log::Log4perl->get_logger();

# Load environment variables from .env file
Env::Dot->import('.env');

my $airtable_exporter = AirtableGPT::Exporter->new(
    airtable_base_id => $ENV{'AIRTABLE_BASE_ID'},
    airtable_api_key => $ENV{'AIRTABLE_API_KEY'},
    logger => $logger
);

$logger->debug("Exporter created" . Data::Dumper->Dump([$airtable_exporter]));
my $results = $airtable_exporter->export_airtable();

my $results_json = JSON->new->utf8->pretty->encode($results);
print $results_json;
