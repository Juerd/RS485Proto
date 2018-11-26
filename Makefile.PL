use 5.020;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME          => 'RS485Proto',
    VERSION_FROM  => 'lib/RS485Proto.pm',
    ABSTRACT_FROM => 'lib/RS485Proto.pod',
    PREREQ_PM     => {  },
    AUTHOR        => 'Juerd Waalboer <juerd@cpan.org>'
);
