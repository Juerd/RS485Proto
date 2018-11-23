#!/usr/bin/perl -w
use strict;
use autodie;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

use RS485Proto;

my $dev = shift;

sub main {
    # Serial port in raw mode
    system "stty", -F => $dev, qw(-icrnl -ixon -ixoff -opost -isig -icanon -echo);
    open my $serial, "<", $dev;

    my $rs485proto = RS485Proto->new(timeout => .3);
    $rs485proto->add($serial);

    while (1) {
        for my $message ($rs485proto->poll) {
            print "Received: $message\n";
        }
    }
}


while (1) {
    eval { main };
    warn $@ if $@;
    sleep 1;
}
