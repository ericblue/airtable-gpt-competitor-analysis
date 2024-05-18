package Util;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(obfuscate_key);

sub obfuscate_key {
    my $key = shift;

    # Obfuscate the key by replacing the middle part with '...'
    my $obfuscated_key = substr($key, 0, 4) . '...' . substr($key, -4);

    return $obfuscated_key;
}

1;

__END__

=head1 NAME

Util - A utility module

=head1 SYNOPSIS

  use Util 'obfuscate_key';

  my $obfuscated_key = obfuscate_key($key);

=head1 DESCRIPTION

This module provides utility functions.

=cut