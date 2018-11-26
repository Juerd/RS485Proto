use strict;
use warnings;

package RS485Proto;

our $VERSION = '1.00';

use IO::Select;
use IO::Handle;
use Time::HiRes qw(time);
use Carp qw(croak carp);
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

    $self->select_output($handle) if not $self->{output};

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
        $handle->sysread(my $buffer, 1024);
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

sub _encode {
    my ($data) = @_;
    my $packet = "";
    for my $octet (map ord, split //, $data) {
        my $msn = $octet >> 4;
        my $lsn = $octet & 0xF;
        $packet .= chr($msn << 4 | ($msn ^ 0xF)) . chr($lsn << 4 | ($lsn ^ 0xF));
    }
    return $packet, chr(crc8($data));
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

        redo if length $$buffer;
    }
    return @messages;
}

sub select_output {
    my ($self, $handle) = @_;

    $handle->autoflush(1);
    $self->{output} = $handle;
}

sub send {
    my ($self, $message) = @_;

    utf8::downgrade($message, 1) or carp "Wide character in send method";
    my ($packet, $crc) = _encode($message);
    $self->{output}->print("$STX$packet$ETX$crc");
}

1;
