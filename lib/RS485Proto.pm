use strict;
use warnings;

package RS485Proto;
use IO::Select;
use Time::HiRes qw(time);
use Carp qw(croak);
use Digest::CRC qw(crc8);

my $STX = "\x02";
my $ETX = "\x03";

sub new {
    my ($class, %args) = @_;
    my $self = {};
    $self->{timeout} = delete $args{timeout};
    $self->{timeout} > 0
        or croak "timeout is mandatory must be greater than 0";

    %args and croak "Unsupported named argument";
    $self->{select} = IO::Select->new;

    return bless $self, $class;
}

sub add {
    my ($self, $handle) = @_;
    $self->{inputs}{$handle} = {
        handle => $handle,
        buffer => "",
    };
    $self->{select}->add($handle);
}

sub _cleanup {
    my ($self) = @_;
    my $now = time;

    for my $input (values %{ $self->{inputs} }) {
        next if not exists $input->{expiry};
        next if $now < $input->{expiry};

        $input->{buffer} = "";
        delete $input->{expiry};
    }
}

sub _read {
    my ($self, $select_timeout) = @_;

    for my $handle ($self->{select}->can_read($select_timeout)) {
        sysread $handle, my $buffer, 1024;
        my $input = $self->{inputs}{$handle};

        $input->{buffer} .= $buffer;
        $input->{expiry} = time() + $self->{timeout};
    }
}

sub _decode {
    my ($packet, $crc) = @_;

    # Verify insane redundancy scheme: wasting 50% in an overly complex way
    # without any error recovery.
    length($packet) % 2 == 0 or return;
    for my $byte (split //, $packet) {
        my $ord = ord $byte;
        $ord >> 4 == (($ord & 0x0F) ^ 0x0F) or return;
    }

    # Decode
    my $num = $packet =~ s/(.)(.)/chr((ord($1) & 0xF0) | (ord($2) >> 4))/seg;
    $num == length($packet) or return;

    # Verify
    ord($crc) == crc8($packet) or return;

    return $packet;
}

sub poll {
    my ($self, $select_timeout) = @_;

    my $now = time;
    $self->_cleanup;
    $self->_read($select_timeout // 1);

    my @messages;

    BUFFER: for my $buffer (map \$_->{buffer}, values %{ $self->{inputs} }) {
        my ($packet, $crc) = $$buffer =~ /$STX (.*?) $ETX (.)/xs or next;
        substr $$buffer, 0, $+[0], "";  # clear buffer up to end of match

        my $message = _decode($packet, $crc);
        push @messages, $message if defined $message;
    }
    return @messages;
}

1;
