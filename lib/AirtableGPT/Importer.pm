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

sub new {
    my ($class, %args) = @_;
    die "Missing required arguments:  airtable_api_key, airtable_base_id" unless
        exists $args{airtable_api_key} &&
            exists $args{airtable_base_id};

    die "Missing required argument: logger" unless exists $args{logger};

    $args{dryrun} //= 0;

    return bless \%args, $class;
}

sub import_airtable_from_data {
    my ($self, $data) = @_;

    $self->{logger}->info("Importing data for company ...");


    my %result = (
        warnings => [],
        errors => [],
        success => { companies => 0, products => 0, features => 0 },
    );

    my $api_key = $self->{airtable_api_key};
    my $base_id = $self->{airtable_base_id};

    my $companies_url = "https://api.airtable.com/v0/$base_id/Companies";
    my $products_url = "https://api.airtable.com/v0/$base_id/Products";
    my $features_url = "https://api.airtable.com/v0/$base_id/Features";

    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => 0x00
    );

    $self->{ua}->default_header('Authorization' => "Bearer $api_key");
    $self->{ua}->default_header('Content-Type' => 'application/json');

    my %existing_companies = $self->fetch_existing_records($companies_url);
    my %existing_products = $self->fetch_existing_records($products_url);
    my %existing_features = $self->fetch_existing_records($features_url);

    my %feature_ids;
    foreach my $feature_data (@{$data->{'Features'}}) {
        my $feature_name = $feature_data->{'Name'};
        if (exists $existing_features{$feature_name}) {
            $self->{logger}->info("Feature '$feature_name' already exists. Skipping.");
            push @{$result{warnings}}, "Feature '$feature_name' already exists. Skipping.";
            $feature_ids{$feature_name} = $existing_features{$feature_name};
        } else {
            my $feature_id = $self->add_record($features_url, { fields => $feature_data });
            if ($feature_id) {
                $result{success}{features}++;
            }
        }
    }

    my $company_id;
    foreach my $company_data (@{$data->{'Companies'}}) {
        $self->{logger}->info("Adding company");
        my $company_name = $company_data->{'Name'};
        $company_data->{'Approx. Number of Employees'} //= 0;

        if (exists $existing_companies{$company_name}) {
            $self->{logger}->info("Company '$company_name' already exists. Skipping.");
            push @{$result{warnings}}, "Company '$company_name' already exists. Skipping.";
            $company_id = $existing_companies{$company_name};
        } else {
            $company_id = $self->add_record($companies_url, { fields => $company_data });
            if ($company_id) {
                $result{success}{companies}++;
            }
        }
    }

    if ($company_id && %feature_ids) {
        $self->{logger}->info("Adding product");
        foreach my $product_data (@{$data->{'Products'}}) {
            my $product_name = $product_data->{'Name'};
            my $company_name = $product_data->{'Company'};
            $product_data->{'Company'} = [$company_id];
            my @feature_names = @{$product_data->{'Features'}};
            my @feature_record_ids = map {$existing_features{$_}} @feature_names;
            $product_data->{'Features'} = \@feature_record_ids;

            if (exists $existing_products{$product_name}) {
                $self->{logger}->info("Product '$product_name' already exists. Skipping.");
                push @{$result{warnings}}, "Product '$product_name' already exists. Skipping.";
            } else {
                my $product_id = $self->add_record($products_url, { fields => $product_data });
                if ($product_id) {
                    $result{success}{products}++;
                }
            }
        }
    }

    return \%result;
}

sub import_airtable {
    my ($self) = @_;

    my %result = (
        warnings => [],
        errors => [],
        success => { companies => 0, products => 0, features => 0 },
    );

    my $api_key = $self->{airtable_api_key};
    my $base_id = $self->{airtable_base_id};

    my $companies_url = "https://api.airtable.com/v0/$base_id/Companies";
    my $products_url = "https://api.airtable.com/v0/$base_id/Products";
    my $features_url = "https://api.airtable.com/v0/$base_id/Features";

    my $json_dir = './json';

    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->ssl_opts(
        verify_hostname => 0,
        SSL_verify_mode => 0x00
    );

    $self->{ua}->default_header('Authorization' => "Bearer $api_key");
    $self->{ua}->default_header('Content-Type' => 'application/json');

    my %existing_companies = $self->fetch_existing_records($companies_url);
    my %existing_products = $self->fetch_existing_records($products_url);
    my %existing_features = $self->fetch_existing_records($features_url);

    my %feature_ids;
    my @feature_files = glob("$json_dir/features/*.json");
    foreach my $file (@feature_files) {
        my $feature_data = $self->read_json_file($file);
        my $feature_name = $feature_data->{'fields'}->{'Name'};
        if (exists $existing_features{$feature_name}) {
            push @{$result{warnings}}, "Feature '$feature_name' already exists. Skipping.";
            $feature_ids{$feature_name} = $existing_features{$feature_name};
        } else {
            my $feature_id = $self->add_record($features_url, $feature_data);
            if ($feature_id) {
                $result{success}{features}++;
            }
        }
    }

    my $company_id;
    my @company_files = glob("$json_dir/companies/*.json");
    if (@company_files) {
        my $company_data = $self->read_json_file($company_files[0]);
        my $company_name = $company_data->{'fields'}->{'Name'};
        $company_data->{'fields'}->{'Approx. Number of Employees'} //= 0;

        if (exists $existing_companies{$company_name}) {
            push @{$result{warnings}}, "Company '$company_name' already exists. Skipping.";
            $company_id = $existing_companies{$company_name};
        } else {
            my $company_id = $self->add_record($companies_url, $company_data);
            if ($company_id) {
                $result{success}{companies}++;
            }
        }
    }

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
                push @{$result{warnings}}, "Product '$product_name' already exists. Skipping.";
            } else {
                my $product_id = $self->add_record($products_url, $product_data);
                if ($product_id) {
                    $result{success}{products}++;
                }
            }
        }
    }

    return \%result;
}

sub add_record {
    my ($self, $url, $data) = @_;

    my $json_data = encode_json($data);

    if ($self->{dryrun}) {
        $self->{'logger'}->info("Dryrun enabled. Would have added record: $json_data");
        return;
    }

    my $response = $self->{ua}->post($url, Content => $json_data);

    if ($response->is_success) {
        $self->{'logger'}->info("Record added successfully.");
        my $content = decode_json($response->decoded_content);
        return $content->{'id'};
    } else {
        my $error_message = "Failed to add record: " . $response->status_line;
        $self->{'logger'}->error($error_message);
        $self->{'logger'}->error($response->decoded_content);
        return $error_message;
    }
}

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

sub read_json_file {
    my ($self, $file_path) = @_;
    my $json_text = read_file($file_path);
    return decode_json($json_text);
}

1;