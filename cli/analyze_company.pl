#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use AirtableGPT::CompanyAnalyzer;
use Getopt::Long;
use Env::Dot;
use Data::Dump;
use Log::Log4perl;
use strict;
use warnings;


=head1 NAME

analyze_company.pl - Script for analyzing company data

=head1 SYNOPSIS

  perl analyze_company.pl <website_url>

=head1 DESCRIPTION

This script analyzes company data and writes the results to JSON files.

=cut

sub usage {
    print "Usage: $0 <website_url>\n";
    print "Options:\n";
    print "  --leverage_existing_features  Leverage existing features (default: 1)\n";
    print "  --help                        Show this help message\n";
    exit;
}


my $leverage_existing_features = 1;


GetOptions(
    'leverage_existing_features=i' => \$leverage_existing_features,
    'help' => \&usage,
) or die "Error in command line arguments\n";

if (@ARGV != 1) {
    usage();
}

my $website_url = $ARGV[0];
my $output_dir = './json';

# Initialize Log4perl
my $log_conf = "$FindBin::Bin/../conf/log4perl.conf";
Log::Log4perl->init($log_conf);
my $logger = Log::Log4perl->get_logger();

# Load environment variables from .env file
my $env_file = "$FindBin::Bin/../.env";
Env::Dot->import($env_file);


my $analyzer = AirtableGPT::CompanyAnalyzer->new(
    openai_api_key => $ENV{'OPENAI_API_KEY'},
    airtable_base_id => $ENV{'AIRTABLE_BASE_ID'},
    airtable_api_key => $ENV{'AIRTABLE_API_KEY'},
    leverage_existing_features => $leverage_existing_features,
    logger => $logger
);

$logger->debug("Analyzer created" . Data::Dumper->Dump([$analyzer]));

$analyzer->analyze($website_url, $output_dir);

