#!/usr/bin/perl
use strict;
use warnings;
use Test::More qw(no_plan);
use RS485Proto;

for my $message ("", "A", "\0", "\xFF", "Hello, world!") {
    my ($packet, $crc) = RS485Proto::_encode($message);
    is(RS485Proto::_decode($packet, $crc), $message, "Encoding round-trips for '$message'");
}

1;
