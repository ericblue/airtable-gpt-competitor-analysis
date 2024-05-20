#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use AirtableGPT::CompanyAnalyzer;
use AirtableGPT::Importer;
use AirtableGPT::Util;
use Getopt::Long;
use Env::Dot;
use Data::Dump;
use Log::Log4perl;
use strict;
use warnings;

sub usage {
    print "Usage: $0 [--file=<file_with_urls>] <website_url1> <website_url2> ...\n";
    print "Options:\n";
    print "  --file=<file_with_urls>       File with website URLs, one per line\n";
    print "  --leverage_existing_features  Leverage existing features (default: 1)\n";
    print "  --help                        Show this help message\n";
    exit;
}

my $leverage_existing_features = 1;
my $file;

GetOptions(
    'file=s' => \$file,
    'leverage_existing_features=i' => \$leverage_existing_features,
    'help' => \&usage,
) or die "Error in command line arguments\n";

my @website_urls;
if (defined $file) {
    open my $fh, '<', $file or die "Could not open file '$file': $!";
    chomp(@website_urls = <$fh>);
    close $fh;
} else {
    @website_urls = @ARGV;
}

if (@website_urls < 1) {
    usage();
}

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

my $airtable_importer = AirtableGPT::Importer->new(
    airtable_base_id => $ENV{'AIRTABLE_BASE_ID'},
    airtable_api_key => $ENV{'AIRTABLE_API_KEY'},
    dryrun => 0,
    logger => $logger
);




# initialize importer with dryrun set to true

foreach my $website_url (@website_urls) {
    $logger->debug("Analyzer created" . Data::Dumper->Dump([$analyzer]));
    my $data = $analyzer->analyze($website_url);
    $logger->debug("Importer created" . Data::Dumper->Dump([$airtable_importer]));

    $logger->info("Data to import: " . Data::Dumper->Dump([$data]) . "\n");
    my $response = $airtable_importer->import_airtable_from_data($data);

    $logger->info("Response: " . Data::Dumper->Dump([$response]) . "\n");

}