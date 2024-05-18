package AirtableExporter;

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Log::Log4perl;
use Data::Dump;
use Util 'obfuscate_key';
use Exporter 'import';

our @EXPORT_OK = qw(new export_airtable);

sub new {
    my ($class, %args) = @_;
    die "Missing required arguments:  airtable_api_key, airtable_base_id" unless
        exists $args{airtable_api_key} &&
            exists $args{airtable_base_id};

    # Ensure logger is passed
    die "Missing required argument: logger" unless exists $args{logger};

    return bless \%args, $class;
}


sub export_airtable {
    my ($self) = @_;

    # Retrieve API key and Base ID from the object
    my $api_key = $self->{airtable_api_key};
    my $base_id = $self->{airtable_base_id};

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
    my @companies = $self->fetch_records($companies_url);
    my @products = $self->fetch_records($products_url);
    my @features = $self->fetch_records($features_url);

    # Fetch existing records
    my %existing_companies = $self->fetch_existing_records($companies_url);
    my %existing_products = $self->fetch_existing_records($products_url);
    my %existing_features = $self->fetch_existing_records($features_url);

    # Format: Key = Company App, value = recgeUgOjlZH4S7OQ
    # for my $key (keys %existing_products) {
    #     print "Key = $key, value = " , $existing_products{$key} , "\n";
    # }


    # Replace record IDs with their corresponding names
    $self->replace_ids_with_names(\@companies, \%existing_companies, \%existing_products, \%existing_features);
    $self->replace_ids_with_names(\@products, \%existing_companies, \%existing_products, \%existing_features);
    $self->replace_ids_with_names(\@features, \%existing_companies, \%existing_products, \%existing_features);


    return {
        Companies => \@companies,
        Products => \@products,
        Features => \@features,
    };
}

=head2 replace_ids_with_names
  $importer->replace_ids_with_names($records, $existing_companies, $existing_products, $existing_features);
=cut
sub replace_ids_with_names {
    my ($self, $records, $existing_companies, $existing_products, $existing_features) = @_;

    # Note: Not entirely efficient, but we have to loop through the records multiple times
    # to replace all occurrences of IDs with their corresponding names

    foreach my $record (@$records) {
        foreach my $key (keys %{$record->{fields}}) {
            if (ref $record->{fields}{$key} eq 'ARRAY') {
                # Handle arrays of IDs
                my @names;
                foreach my $id (@{$record->{fields}{$key}}) {
                    if ($id =~ /^rec[A-Za-z0-9]+$/) {
                        my $name;
                        while (my ($k, $v) = each %$existing_companies) {
                            if ($v eq $id) {
                                $name = $k;
                                last;
                            }
                        }
                        while (my ($k, $v) = each %$existing_products) {
                            if ($v eq $id) {
                                $name = $k;
                                last;
                            }
                        }
                        while (my ($k, $v) = each %$existing_features) {
                            if ($v eq $id) {
                                $name = $k;
                                last;
                            }
                        }
                        push @names, $name if $name;
                    }
                }
                $record->{fields}{$key} = \@names;
            } elsif ($record->{fields}{$key} =~ /^rec[A-Za-z0-9]+$/) {
                # Handle single IDs
                my $name;
                while (my ($k, $v) = each %$existing_companies) {
                    if ($v eq $record->{fields}{$key}) {
                        $name = $k;
                        last;
                    }
                }
                while (my ($k, $v) = each %$existing_products) {
                    if ($v eq $record->{fields}{$key}) {
                        $name = $k;
                        last;
                    }
                }
                while (my ($k, $v) = each %$existing_features) {
                    if ($v eq $record->{fields}{$key}) {
                        $name = $k;
                        last;
                    }
                }
                $record->{fields}{$key} = $name if $name;
            }
        }
    }
}

sub fetch_records {
    my ($self, $url) = @_;
    my @records;
    my $offset;

    do {
        my $fetch_url = $url;
        $fetch_url .= "?offset=$offset" if $offset;
        my $response = $self->{ua}->get($fetch_url);

        if ($response->is_success) {
            my $content = decode_json($response->decoded_content);
            push @records, @{$content->{'records'}};
            $offset = $content->{'offset'};
        } else {
            $self->{'logger'}->info("Failed to fetch records: ", $response->status_line);
            $self->{'logger'}->info($response->decoded_content);
            last;
        }
    } while ($offset);

    return @records;
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


1;

__END__

=head1 NAME

AirtableExporter - A module for exporting data from Airtable

=head1 SYNOPSIS

  use AirtableExporter;

  my $exporter = AirtableExporter->new(
    api_key => 'your_api_key',
    base_id => 'your_base_id',
  );

  my $data = $exporter->export_airtable;

=head1 DESCRIPTION

This module provides methods for exporting data from Airtable.

=cut