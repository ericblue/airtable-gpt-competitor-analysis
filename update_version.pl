#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

my $file = 'lib/AirtableGPT/Version.pm';
my $new_version;

# Parse command-line options
GetOptions('version=s' => \$new_version) or die "Usage: $0 --version v0.1\n";

# Check if version is provided and it matches the required format
unless (defined $new_version && $new_version =~ /^v\d+(\.\d+)*$/) {
    die "A version number in the format of v0.1, v1.0, v1.1.1 etc is required.\n";
}

# Read the file content
open my $in, '<', $file or die "Can't read $file: $!";
my @lines = <$in>;
close $in;

# Process each line
for my $line (@lines) {
    if ($line =~ /(our\s+\$VERSION\s*=\s*')([^']+)'/) {
        my $prefix = $1;
        my $version = $2;
        $line =~ s/(our\s+\$VERSION\s*=\s*')[^']+/$1$new_version/;
    }
}

# Write the updated content back to the file
open my $out, '>', $file or die "Can't write $file: $!";
print $out @lines;
close $out;

print "Updated version to $new_version\n";