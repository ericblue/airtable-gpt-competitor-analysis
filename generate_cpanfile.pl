#!/usr/bin/env perl

use strict;
use warnings;
use Module::ExtractUse;
use Data::Dump;
use Pod::Usage;

my $p = Module::ExtractUse->new;

# Specify the directories to scan for dependencies
my @directories = ('.', 'lib');

# get a list of all .pl and .pm files located in the directories
my @files = map { glob "$_/*.pm $_/*.pl" } @directories;

print "Analyzing files: @files\n";

# get the module names for files in lib dir
my @local_modules = map { glob "$_/*.pm" } 'lib';
# strip prefix lib/ and suffix .pm
for (@local_modules) {
    s/^lib\///;
    s/\.pm$//;
}
print "Ignoring local modules: @local_modules\n\n";

my %dependencies;

foreach my $file (@files) {
    # Extract the modules used in the file
    $p->extract_use($file);
    print "File = $file\n";

    my $used = $p->used;
    # remove from used if modules is in local_modules
    for my $module (@local_modules) {
        delete $used->{$module};
    }

    # ignore internal perl modules like lib, strict, warnings, etc.
    delete $used->{$_} for qw(lib strict warnings utf8 vars subs feature);

    # append used modules to the dependencies hash
    $dependencies{$_} = 1 for keys %$used;
}

#dd \%dependencies;

# Generate the cpanfile content
my $cpanfile_content = '';
foreach my $module (sort keys %dependencies) {
    $cpanfile_content .= "requires '$module';\n";
}

# Write the cpanfile
open my $cpanfile, '>', 'cpanfile' or die "Cannot open cpanfile: $!";
print "\nGenerated cpanfile:\n$cpanfile_content\n";
print $cpanfile $cpanfile_content;
close $cpanfile;

print "Modules can be installed using 'cpanm --installdeps .'\n";
print "Or using carton: 'carton install'\n";
print "Note: to run with carton: 'carton exec perl your_script.pl' to run the script\n";

# Display the perldocs if the user runs the script with the --help or -h option
pod2usage(1) if @ARGV == 1 and $ARGV[0] =~ /^--?h(?:elp)?$/;

__END__

=head1 NAME

generate_cpanfile.pl - Generate a cpanfile from the modules used in a Perl script or module

=head1 SYNOPSIS

perl generate_cpanfile.pl

=head1 DESCRIPTION

This script scans the current directory and the 'lib' directory for .pl and .pm files, extracts the modules used in these files, and generates a cpanfile listing these modules.

=head1 VERSION

1.0.0

=head1 RELEASE DATE

2024-05-17

=head1 AUTHOR

Eric Blue <ericblue76@gmail.com>
Website: https://eric-blue.com

=cut
```
