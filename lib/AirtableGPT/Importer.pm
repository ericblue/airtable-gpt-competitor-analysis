package AirtableGPT::Importer;

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use File::Slurp;
use Log::Log4perl;
use Data::Dump;
use AirtableGPT::Util 'obfuscate_key';
use Exporter 'import';

our @EXPORT_OK = qw(new import_airtable fetch_existing_records read_json_file);

=head1 NAME

AirtableGPT::Importer - A module for importing competitor data to Airtable

=head1 SYNOPSIS

  use AirtableGPT::Importer;

  my $importer = AirtableGPT::Importer->new(
    airtable_api_key => 'your_api_key',
    airtable_base_id => 'your_base_id',
  );

  $importer->import_airtable;

=head1 DESCRIPTION

This module provides methods for importing data from Airtable.

=cut

=head2 new

  my $importer = AirtableImporter->new(%args);

Creates a new AirtableImporter object.

=cut

sub new {
    my ($class, %args) = @_;
    die "Missing required arguments:  airtable_api_key, airtable_base_id" unless
        exists $args{airtable_api_key} &&
        exists $args{airtable_base_id};

    # Ensure logger is passed
    die "Missing required argument: logger" unless exists $args{logger};

    return bless \%args, $class;
}


=head2 import_airtable_from_data()

  $importer->import_airtable_from_json($json_data);

Imports data to Airtable from JSON data - e.g. output from /analyze endpoint or output from analyzer module

=cut

sub import_airtable_from_data {
    my ($self, $data) = @_;

    #dd $data;
    # TODO Refactor both import_airtable_from_json and import_airtable to extract common code

    # Retrieve API key and Base ID from the object
    my $api_key = $self->{airtable_api_key};
    my $base_id = $self->{airtable_base_id};

    # Obfuscate api_key and print out the api key and base id
    my $obfuscated_api_key = obfuscate_key($api_key);
    $self->{'logger'}->info("API Key: $obfuscated_api_key");
    $self->{'logger'}->info("Base ID: $base_id");

    # Airtable API URLs
    my $companies_url = "https://api.airtable.com/v0/$base_id/Companies";
    my $products_url = "https://api.airtable.com/v0/$base_id/Products";
    my $features_url = "https://api.airtable.com/v0/$base_id/Features";

    # Create a user agent
    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => 0x00
    );

    # Set authorization header
    $self->{ua}->default_header('Authorization' => "Bearer $api_key");
    $self->{ua}->default_header('Content-Type' => 'application/json');

    # Fetch existing records
    my %existing_companies = $self->fetch_existing_records($companies_url);
    my %existing_products = $self->fetch_existing_records($products_url);
    my %existing_features = $self->fetch_existing_records($features_url);

    #dd %existing_features;

    my %feature_ids;
    foreach my $feature_data (@{$data->{'Features'}}) {
        my $feature_name = $feature_data->{'Name'};
        if (exists $existing_features{$feature_name}) {
            $self->{'logger'}->info("Feature '$feature_name' already exists. Skipping.");
            $feature_ids{$feature_name} = $existing_features{$feature_name};
        } else {
            my $feature_id = $self->add_record($features_url, { fields => $feature_data });
            $self->{'logger'}->info("Adding feature '$feature_name'");
            $feature_ids{$feature_name} = $feature_id if $feature_id;
        }
    }


    my $company_id;
    foreach my $company_data (@{$data->{'Companies'}}) {
        my $company_name = $company_data->{'Name'};
        $company_data->{'Approx. Number of Employees'} //= 0;  # Default to 0 if not specified

        if (exists $existing_companies{$company_name}) {
            $self->{'logger'}->info("Company '$company_name' already exists. Skipping.");
            $company_id = $existing_companies{$company_name};
        } else {
            $self->{'logger'}->info("Adding company '$company_name'");
            $company_id = $self->add_record($companies_url, { fields => $company_data });
        }
    }

    # Process product JSON files using captured company and feature IDs
    #dd %feature_ids;
    if ($company_id && %feature_ids) {
        foreach my $product_data (@{$data->{'Products'}}) {
            my $product_name = $product_data->{'Name'};
            my $company_name = $product_data->{'Company'};
            $product_data->{'Company'} = [$company_id];
            my @feature_names = @{$product_data->{'Features'}};
            my @feature_record_ids = map {$existing_features{$_}} @feature_names;
            $product_data->{'Features'} = \@feature_record_ids;

            if (exists $existing_products{$product_name}) {
                $self->{'logger'}->info("Product '$product_name' already exists. Skipping.");
            }
            else {
                $self->{'logger'}->info("Adding product '$product_name'");
                #dd { fields => $product_data };
                $self->add_record($products_url, { fields => $product_data });
            }
        }
    }

}

=head2 import_airtable

  $importer->import_airtable;

Imports data from Airtable.

=cut

sub import_airtable {
    my ($self) = @_;

    # Retrieve API key and Base ID from the object
    my $api_key = $self->{airtable_api_key};
    my $base_id = $self->{airtable_base_id};

    # Obfuscate api_key and print out the api key and base id
    my $obfuscated_api_key = substr($api_key, 0, 4) . '...' . substr($api_key, -4);
    $self->{'logger'}->info("API Key: $obfuscated_api_key");
    $self->{'logger'}->info("Base ID: $base_id");

    # Airtable API URLs
    my $companies_url = "https://api.airtable.com/v0/$base_id/Companies";
    my $products_url = "https://api.airtable.com/v0/$base_id/Products";
    my $features_url = "https://api.airtable.com/v0/$base_id/Features";

    # Directory containing the JSON files
    my $json_dir = './json';

    # Create a user agent
    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => 0x00
    );

    # Set authorization header
    $self->{ua}->default_header('Authorization' => "Bearer $api_key");
    $self->{ua}->default_header('Content-Type' => 'application/json');

    # Fetch existing records
    my %existing_companies = $self->fetch_existing_records($companies_url);
    my %existing_products = $self->fetch_existing_records($products_url);
    my %existing_features = $self->fetch_existing_records($features_url);

   foreach my $key (keys %existing_features) {
       $self->{'logger'}->debug("$key => $existing_features{$key}");
   }

    # Process feature JSON files first to get their IDs
    my %feature_ids;
    my @feature_files = glob("$json_dir/features/*.json");
    foreach my $file (@feature_files) {
        my $feature_data = $self->read_json_file($file);
        my $feature_name = $feature_data->{'fields'}->{'Name'};
        if (exists $existing_features{$feature_name}) {
            $self->{'logger'}->info("Feature '$feature_name' already exists. Skipping.");
            $feature_ids{$feature_name} = $existing_features{$feature_name};
        } else {
            my $feature_id = $self->add_record($features_url, $feature_data);
            $self->{'logger'}->info("Adding feature '$feature_name'");
            $feature_ids{$feature_name} = $feature_id if $feature_id;
        }
    }

    # Process company JSON file
    my $company_id;
    my @company_files = glob("$json_dir/companies/*.json");
    if (@company_files) {
        my $company_data = $self->read_json_file($company_files[0]);
        my $company_name = $company_data->{'fields'}->{'Name'};
        $company_data->{'fields'}->{'Approx. Number of Employees'} //= 0;  # Default to 0 if not specified

        if (exists $existing_companies{$company_name}) {
            $self->{'logger'}->info("Company '$company_name' already exists. Skipping.");
            $company_id = $existing_companies{$company_name};
        } else {
            $self->{'logger'}->info("Adding company '$company_name'");
            $company_id = $self->add_record($companies_url, $company_data);
        }
    }

    # Process product JSON files using captured company and feature IDs
    if ($company_id && %feature_ids) {
        my @product_files = glob("$json_dir/products/*.json");
        foreach my $file (@product_files) {
            my $product_data = $self->read_json_file($file);
            my $product_name = $product_data->{'fields'}->{'Name'};
            $product_data->{'fields'}->{'Company'} = [$company_id];
            my @feature_names = @{$product_data->{'fields'}->{'Features'}};
            my @feature_record_ids = map { $feature_ids{$_} } @feature_names;
            $product_data->{'fields'}->{'Features'} = \@feature_record_ids;

            if (exists $existing_products{$product_name}) {
                $self->{'logger'}->info("Product '$product_name' already exists. Skipping.");
            } else {
                $self->{'logger'}->info("Adding product '$product_name'");
                #dd $product_data;
                $self->add_record($products_url, $product_data);
            }
        }
    }
}

=head2 add_record

  $importer->add_record($url, $data);

Adds a record to Airtable.

=cut

sub add_record {
    my ($self, $url, $data) = @_;
    my $json_data = encode_json($data);
    my $response = $self->{ua}->post($url, Content => $json_data);

    if ($response->is_success) {
        $self->{'logger'}->info("Record added successfully.");
        my $content = decode_json($response->decoded_content);
        return $content->{'id'};
    } else {
        $self->{'logger'}->info("Failed to add record: ", $response->status_line);
        $self->{'logger'}->info($response->decoded_content);
        return undef;
    }
}

=head2 fetch_existing_records

  $importer->fetch_existing_records($url);

Fetches existing records from Airtable.

=cut

sub fetch_existing_records {
    my ($self, $url) = @_;
    my %existing_records;
    my $offset;

    do {
        my $fetch_url = $url;
        $fetch_url .= "?offset=$offset" if $offset;
        my $response = $self->{ua}->get($fetch_url);

        if ($response->is_success) {
            my $content = decode_json($response->decoded_content);
            foreach my $record (@{$content->{'records'}}) {
                $existing_records{$record->{'fields'}->{'Name'}} = $record->{'id'};
            }
            $offset = $content->{'offset'};
        } else {
            $self->{'logger'}->info("Failed to fetch records: ", $response->status_line);
            $self->{'logger'}->info($response->decoded_content);
            last;
        }
    } while ($offset);

    return %existing_records;
}

=head2 read_json_file

  $importer->read_json_file($file_path);

Reads a JSON file and returns the data.

=cut

sub read_json_file {
    my ($self, $file_path) = @_;
    my $json_text = read_file($file_path);
    return decode_json($json_text);
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