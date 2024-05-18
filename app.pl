#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/./lib";
use CompanyAnalyzer;
use AirtableImporter;
use AirtableExporter;
use Util 'obfuscate_key';
use Env::Dot;
use Mojolicious::Lite;
use Mojolicious::Plugin::OpenAPI;
use Mojolicious::Plugin::SwaggerUI;
use Log::Log4perl::Level;
use Log::Log4perl;
use Data::Dump;
use JSON;

use strict;
use warnings;

# Initialize Log4perl
my $log_conf = "$FindBin::Bin/./conf/log4perl.conf";
Log::Log4perl->init($log_conf);
my $logger = Log::Log4perl->get_logger();

sub set_log_level {

    my $logger = shift;

    # Define a hash that maps log level strings to Log4perl constants
    my %log_levels = (
        'DEBUG' => $DEBUG,
        'INFO'  => $INFO,
        'WARN'  => $WARN,
        'ERROR' => $ERROR,
        'FATAL' => $FATAL,
    );

    # Get the log level from the LOG_LEVEL environment variable
    my $log_level = $ENV{'LOG_LEVEL'};

    # Set the log level if the LOG_LEVEL environment variable exists and is a recognized log level
    if (defined $log_level && exists $log_levels{$log_level}) {
        $logger->level($log_levels{$log_level});
    }

}


sub get_current_log_level {
    my $logger = shift;

    # Get current log level
    my $current_log_level = $logger->level();

    # Convert log level to string
    my $log_level_str = Log::Log4perl::Level::to_level($current_log_level);

    return $log_level_str;
}

# Change the static_paths setting
app->static->paths->[0] = './resources/public';

# Route to serve static files from a directory
get '/' => sub {
    my $c = shift;
    $c->reply->static('index.html');
};

get '/api/config' => sub {
    my $c = shift;

    my %config = (
        'OPENAI_API_KEY' => obfuscate_key($ENV{'OPENAI_API_KEY'}),
        'AIRTABLE_BASE_ID' => $ENV{'AIRTABLE_BASE_ID'},
        'AIRTABLE_API_KEY' => obfuscate_key($ENV{'AIRTABLE_API_KEY'}),
        'LOG_LEVEL' => $ENV{'LOG_LEVEL'},
    );

    $c->render(json => \%config);
} => 'config';

get '/api/analyze' => sub {
    my $c = shift;
    my $website_url = $c->param('website_url');

    my $leverage_existing_features = 1;
    my $analyzer = CompanyAnalyzer->new(
        openai_api_key => $ENV{'OPENAI_API_KEY'},
        airtable_base_id => $ENV{'AIRTABLE_BASE_ID'},
        airtable_api_key => $ENV{'AIRTABLE_API_KEY'},
        leverage_existing_features => $leverage_existing_features,
        logger => $logger
    );

    $logger->debug("Analyzer created" . Data::Dumper->Dump([$analyzer]));

    my $result = $analyzer->analyze($website_url);

    $c->render(json => $result);

} => 'analyze';

post '/api/import' => sub {
    my $c = shift;
    my $data = $c->req->json;

    my $airtable_importer = AirtableImporter->new(
        airtable_base_id => $ENV{'AIRTABLE_BASE_ID'},
        airtable_api_key => $ENV{'AIRTABLE_API_KEY'},
        logger => $logger
    );

    $logger->debug("Importer created" . Data::Dumper->Dump([$airtable_importer]));
    $airtable_importer->import_airtable_from_data($data);

    my $result = "SUCCESS";
    $c->render(json => { result => $result });
} => 'import';

get '/api/analyze-and-import' => sub {
    my $c = shift;
    my $website_url = $c->param('website_url');

    my $leverage_existing_features = 1;
    my $analyzer = CompanyAnalyzer->new(
        openai_api_key => $ENV{'OPENAI_API_KEY'},
        airtable_base_id => $ENV{'AIRTABLE_BASE_ID'},
        airtable_api_key => $ENV{'AIRTABLE_API_KEY'},
        leverage_existing_features => $leverage_existing_features,
        logger => $logger
    );

    $logger->debug("Analyzer created" . Data::Dumper->Dump([$analyzer]));

    my $data = $analyzer->analyze($website_url);

    my $airtable_importer = AirtableImporter->new(
        airtable_base_id => $ENV{'AIRTABLE_BASE_ID'},
        airtable_api_key => $ENV{'AIRTABLE_API_KEY'},
        logger => $logger
    );

    $logger->debug("Importer created" . Data::Dumper->Dump([$airtable_importer]));

    $airtable_importer->import_airtable_from_data($data);

    my $result = "SUCCESS";
    $c->render(json => { result => $result });

} => 'analyze-and-import';

get '/api/export' => sub {
    my $c = shift;

    my $airtable_exporter = AirtableExporter->new(
        airtable_base_id => $ENV{'AIRTABLE_BASE_ID'},
        airtable_api_key => $ENV{'AIRTABLE_API_KEY'},
        logger => $logger
    );

    $logger->debug("Exporter created" . Data::Dumper->Dump([$airtable_exporter]));
    my $result = $airtable_exporter->export_airtable();

    $c->render(json => $result);

} => 'analyze';

plugin OpenAPI => {
    url => 'api.yaml',
    route => app->routes->any('/api')
};
plugin 'SwaggerUI' => {
    route => app->routes()->any('/swagger'),
    url => '/api',
};

# Set log level
set_log_level($logger);

my $log_level = get_current_log_level($logger);
$logger->info("Log level set to $log_level");

my $host = $ENV{'HOST'} // 'localhost';
my $port = $ENV{'PORT'} // '3000';

app->start('daemon', '-l', "http://$host:$port");
