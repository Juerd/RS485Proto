#!/usr/bin/perl
use strict;
use warnings;
use Test::More qw(no_plan);
use Digest::CRC qw(crc8);

require_ok "RS485Proto" or BAIL_OUT "Can't even load the module";

my @tests = (
    {
        m      => "\xFA\0\xBE",
        m_enc  => "\xF0\xA5\x0F\x0F\xB4\xE1",
        c      => "\xCA",
        c_enc  => "\xC3\xA5",
    },
    {
        m      => "\xFA\0\xB4",
        m_enc  => "\xF0\xA5\x0F\x0F\xB4\x4B",
        c      => "\xB4",
        c_enc  => "\xB4\x4B",
    }
);

for my $t (@tests) {
    subtest "Message " . unpack("H*", $t->{m}), sub {
        plan tests => 3;

        is(RS485Proto::_crc8maxim($t->{m}), $t->{c}, "crc8 is as expected");
        is(RS485Proto::_encode($t->{m}), $t->{m_enc}, "Message encodes correctly");
        is(RS485Proto::_encode($t->{c}), $t->{c_enc}, "CRC encodes correctly");
    }
}

1;
