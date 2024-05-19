package AirtableGPT::CompanyAnalyzer;
use strict;
use warnings;
use LWP::UserAgent;
use LWP::Protocol::https;
use JSON;
use File::Slurp;
use File::Path 'make_path';
use Cwd 'abs_path';
use Data::Dump;
use Encode qw(encode_utf8);
use Log::Log4perl;
use Exporter 'import';
use utf8;

our @EXPORT_OK = qw(new analyze send_request fetch_existing_records write_json_files);

binmode STDOUT, ':utf8';

=head1 NAME

CompanyAnalyzer - A module for analyzing competitor data from a given website URL

=head1 SYNOPSIS

  use AirtableGPT::CompanyAnalyzer;

  my $analyzer = AirtableGPT::CompanyAnalyzer->new(
    openai_api_key => 'openai api key'',
    airtable_base_id => 'airtable base id'',
    airtable_api_key => 'airtable api key',
    leverage_existing_features => boolean (1 or 0),
  );

  my $result = $analyzer->analyze($website_url, $output_dir);
  print $result;

=head1 DESCRIPTION

This module provides methods for analyzing company data.

=cut

=head2 new

  my $analyzer = AirtableGPT::CompanyAnalyzer->new(%args);

Creates a new AirtableGPT::CompanyAnalyzer object.

=cut

sub new {
    my ($class, %args) = @_;

    die "Missing required arguments: openai_api_key, airtable_api_key, airtable_base_id" unless
        exists $args{openai_api_key} &&
            exists $args{airtable_api_key} &&
            exists $args{airtable_base_id};

    # If leverage_existing_features, default to 1
    $args{leverage_existing_features} = 1 unless exists $args{leverage_existing_features};

    # Ensure logger is passed
    die "Missing required argument: logger" unless exists $args{logger};

    return bless \%args, $class;
}

=head2 analyze

  $analyzer->analyze($website_url, $output_dir);

Analyzes the company data and saves JSON files to the output directory

=cut
sub analyze {
    my ($self, $website_url, $output_dir) = @_;

    my $data = $self->send_request($website_url);

    # Output directory specified, writing JSON to disk
    if ($output_dir) {
        $self->write_json_files($data, $output_dir);
        $self->{logger}->info("JSON files created at $output_dir");
        return 1;

    }

    # Otherwise return JSON data
    return $data;

}

=head2 send_request

  $analyzer->send_request($website_url);

Sends a request to the OpenAI API.

=cut
sub send_request {
    my ($self, $website_url) = @_;

    my $features_url = "https://api.airtable.com/v0/$self->{'airtable_base_id'}/Features";
    my %existing_features = $self->fetch_existing_records($features_url);
    $self->{logger}->debug("Existing features " . Data::Dumper->Dump([ \%existing_features ]));

    my $feature_instructions = "";

    if ($self->{leverage_existing_features}) {
        $self->{logger}->info("Leveraging existing features");
        $feature_instructions = "For features please try to use existing definitions from the following list:";

        foreach my $feature (keys %existing_features) {
            $feature_instructions .= "- $feature\n";
        }

        $feature_instructions .= "Only include features from this list if you are certain the functionality is present.  Only add a new feature if you feel it is important or useful and not already covered by the existing features.";

    }
    else {
        $self->{logger}->info("Not leveraging existing features");
    }

    # Note: The prompt is a heredoc string that contains the instructions for the OpenAI API
    # Any major changes to the prompt and fields will require updates to api.yaml and have a
    # cascading effect on the OpenAPI schema and the generated code, and AirtableGPT::AirtableImporter class

    my $prompt = <<"END_PROMPT";
I need to analyze the website $website_url and extract information to create JSON files for companies, products, and features.

$feature_instructions

The JSON output should adhere to the following structure and rules and should be in strict JSON format:

#### Companies
- **Fields:**
  - Name (String): The name of the company.
  - Founded (Integer): The year the company was founded.
  - Approx. Number of Employees (Integer): The number of employees. If undisclosed, set to 0.
  - Company URL (String): The URL of the company’s website.

  (Note: the following fields are custom extensions beyond the default Competitor Tracking Airtable schema)

  - VC Funding (Boolean): Whether the company has VC funding.
  - Funding Amount (Integer): The amount of funding in dollars.
  - Investors (String): Names of investors.
  - Press Link (String): URL to a press link.

#### Products
- **Fields:**
  - Name (String): The name of the product.
  - Company (String): The name of the company offering the product.
  - Target Audience(s) (Array of Strings): The target audience, limited to "Academia", "Corporate", or "Personal".
  - Features (Array of Strings): Features associated with the product.
  - Messaging (String): Product messaging.
  - Pricing (String): Pricing information.
  - Add'l Notes (String): Additional notes.
  - Website (String): Product website URL.

#### Features
- **Fields:**
  - Name (String): The name of the feature.
  - Description (String): A description of the feature.
  - Do we have this feature? (Boolean): Whether the feature is available.

Please analyze the website $website_url and generate the required JSON files for each entity based on the structure and rules provided. The output should be in strict JSON format only, without any additional text or explanations.
END_PROMPT

    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => 0x00
    );
    $ua->default_header('Content-Type' => 'application/json');
    $ua->default_header('Authorization' => "Bearer $self->{openai_api_key}");

    $self->{logger}->info("Analyzing company $website_url...");

    my $response = $ua->post(
        'https://api.openai.com/v1/chat/completions',
        Content => encode_utf8(encode_json({
            model    => 'gpt-4o',
            messages => [ { role => 'user', content => $prompt } ],
        }))
    );

    if ($response->is_success) {
        my $content = decode_json($response->decoded_content);
        #print Data::Dumper->Dump([$content->{"choices"}[0]{"message"}->{"content"}]);
        my $json_text = $content->{choices}[0]{message}{content};
        $json_text =~ s/.*```json\n(.*)\n```/$1/s; # Extract the JSON part
        return decode_json($json_text);
    }
    else {
        die "Failed to send request: " . $response->status_line;
    }

}

=head2 fetch_existing_records

  $analyzer->fetch_existing_records($url);

Fetches existing records from Airtable.

=cut

sub fetch_existing_records {

    my ($self, $url) = @_;
    my %existing_records;
    my $offset;

    # Create a user agent
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => 0x00
    );

    # Set authorization header
    $ua->default_header('Authorization' => "Bearer $self->{airtable_api_key}");
    $ua->default_header('Content-Type' => 'application/json');

    do {
        my $fetch_url = $url;
        $fetch_url .= "?offset=$offset" if $offset;
        my $response = $ua->get($fetch_url);

        if ($response->is_success) {
            my $content = decode_json($response->decoded_content);
            foreach my $record (@{$content->{'records'}}) {
                $existing_records{$record->{'fields'}->{'Name'}} = $record->{'id'};
            }
            $offset = $content->{'offset'};
        }
        else {
            $self->{logger}->info("Failed to fetch records: ", $response->status_line, "\n");
            $self->{logger}->info($response->decoded_content, "\n");
            #last;
        }
    } while ($offset);

    return %existing_records;
}

=head2 write_json_files

  $analyzer->write_json_files($data, $output_dir);

Writes the analyzed data to JSON files.

=cut

sub write_file_utf8 {
    my ($self, $file_path, $data) = @_;

    open my $fh, '>', $file_path or die "Could not open '$file_path' for writing: $!";
    binmode($fh, ":utf8"); # Set the file handle to UTF-8
    print $fh $data;
    close $fh;
}

sub write_json_files {
    my ($self, $data, $output_dir) = @_;

    $self->{logger}->info("Writing JSON files to $output_dir");

    make_path("$output_dir/companies");
    make_path("$output_dir/products");
    make_path("$output_dir/features");

    # delete existing json files in those directories
    unlink glob "$output_dir/companies/*";
    unlink glob "$output_dir/products/*";
    unlink glob "$output_dir/features/*";

    # Create a JSON object with pretty printing enabled
    my $json = JSON->new->pretty(1);

    #dd $data;

    # check if Companies key exists, otherwise use lower case companies
    if (!exists $data->{Companies}) {
        $data->{Companies} = $data->{companies};
    }

    $data->{companies_fields} = { fields => $data->{Companies}->[0] };
    $self->write_file_utf8("$output_dir/companies/company.json", $json->encode($data->{companies_fields}));

    # check if Products key exists, otherwise use lower case products
    if (!exists $data->{Products}) {
        $data->{Products} = $data->{products};
    }

    $data->{products_fields} = { fields => $data->{Products}->[0] };
    $self->write_file_utf8("$output_dir/products/product.json", $json->encode($data->{products_fields}));

    # check if Features key exists, otherwise use lower case features
    if (!exists $data->{Features}) {
        $data->{Features} = $data->{features};
    }

    for my $i (0 .. $#{$data->{Features}}) {
        $data->{features_fields} = { fields => $data->{Features}[$i] };
        $self->write_file_utf8("$output_dir/features/feature_$i.json", $json->encode($data->{features_fields}));
    }

}

1;

__END__

=head1 AUTHOR

Eric Blue <ericblue76@gmail.com>
Website: https://eric-blue.com

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Eric Blue

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut