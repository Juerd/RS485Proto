#!/usr/bin/perl
use strict;
use warnings;
use Test::More qw(no_plan);
use RS485Proto;


my @messages = ("", "A", "\0", "\xFF", "Hello, world!");

subtest "Encoding round-trips" => sub {
    plan tests => scalar @messages;

    for my $message (@messages) {
        my ($packet, $crc) = RS485Proto::_encode($message);
        is(RS485Proto::_decode($packet, $crc), $message,
            "Message: '" . unpack("H*", $message) . "'");
    }
};

pipe my $r, my $w;

my $p = RS485Proto->new(timeout => 1);
$p->add($r);
$p->select_output($w);
$p->send($_) for @messages;
my @received = $p->poll;
is_deeply(\@messages, \@received, "Round-trip of buffered queue of messages");

1;
