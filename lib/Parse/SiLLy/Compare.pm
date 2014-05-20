package Parse::SiLLy::Compare;
use strict;
use warnings;

# --------------------------------------------------------------------
use Exporter;
@Parse::SiLLy::Compare::ISA= qw(Exporter);
@Parse::SiLLy::Compare::EXPORT=qw(compareR);

use Carp;

# --------------------------------------------------------------------
# @return whether the given LHS matches the given RHS. If they do not
# match, stores the reason in the given holder (an array whose first
# element is used to return a textual explanation why the match
# failed.

# This code started its life as Data::Compare, by Fabien Tassin
# fta@sofaraway.org, kudos for publishing it! This version here is
# heavily modified, so that almost just the concept of the original
# remains. Of course, any errors here are mine, not his.

sub compareR( $$$ );
sub compareR( $$$ )
{
    croak "Usage: compareR(lhs, rhs, reason_holder)\n" unless $#_ == 2;
    my ($x, $y, $reason_holder)= (@_);

    my $refx= ref($x);
    my $refy= ref($y);

    if ( ! defined($x)) {
        if ( ! defined($y)) {   # both are undefined
            return 1;
        }
        else {
            $reason_holder->[0] = "LHS is not defined, but RHS is: ".$y;
            return 0;
        }
    }
    # From here on, $x is defined.
    if ( ! defined($y)) {
        $reason_holder->[0] = "RHS is not defined, but LHS is: ".$x;
        return 0;
    }
    # From here on, $y is defined, too.

    if ('' eq $refx && '' eq $refy) { # both are scalars
        if ($x eq $y) {               # both are defined and equal
            return 1;
        }
        else {
            $reason_holder->[0] = "not equal: ".$x.", ".$y;
            return 0;
        }
    }
    # From here on, one at least is not a scalar

    if ($refx ne $refy) {       # not the same type
        $reason_holder->[0] = "LHS (a $refx) and RHS (a $refy) not of the same type.";
        return 0;
    }
    if ($x == $y) {             # exactly the same reference
        return 1;
    }

    if ($refx eq 'SCALAR') {
        my $result= compareR($$x, $$y, $reason_holder);
        if ($result) {
            return 1;
        }
        else {
            $reason_holder->[0]= "References to scalars do not match because".
                $reason_holder->[0];
            return 0;
        }
    }

    if ($refx eq 'ARRAY') {
        if ($#$x != $#$y) {
            $reason_holder->[0] = "arrays differ in lengths: ".
                scalar(@$x).", ".scalar(@$y).": ".$x.", ".$y;
            return 0;
        }
        # same length
        my $i = 0;
        for (@$x) {
            if ( ! compareR($$x[$i], $$y[$i], $reason_holder)) {
                $reason_holder->[0]= "arrays differ at index $i, because ".
                    $reason_holder->[0];
                return 0;
            }
            ++$i;
        }
        return 1;
    }

    if ($refx eq 'HASH') {
        if (scalar(keys(%$x)) != scalar(keys(%$y))) {
            $reason_holder->[0] = "hashes differ in number of keys: ".
                scalar(keys(%$x)).", ".scalar(keys(%$y));
            return 0;
        }
        for (keys(%$x)) {
            if ( ! exists($y->{$_})) {
                $reason_holder->[0] =
                    "hashes differ: key '$_' exists in LHS, but not in RHS";
                return 0;
            }
            # Optimization:
            #if ( ! defined($x->{$_}) && ! defined($y->{$_})) { next; }

            if ( ! compareR($x->{$_}, $y->{$_}, $reason_holder)) {
                $reason_holder->[0] = "hashes differ in key '$_': ".
                    $reason_holder->[0];
                return 0;
            }
        }
        return 1;
    }

    if ($refx eq 'REF') {
        $reason_holder->[0]= "we consider ref objects to be different";
        return 0;
    }
    if ($refx eq 'CODE') {
        return 1; # changed for log4perl, let's just identify all coderefs
    }
    if ($refx eq 'GLOB') {
        $reason_holder->[0]= "we consider ref objects to be different";
        return 0;
    }

    # a package name (object blessed)
    my ($type) = "$x" =~ m/^$refx=(\S+)\(/o;
    if ($type eq 'HASH') {
        my %x = %$x;
        my %y = %$y;
        return compareR(\%x, \%y, $reason_holder);
    }
    if ($type eq 'ARRAY') {
        my @x = @$x;
        my @y = @$y;
        return compareR(\@x, \@y, $reason_holder);
    }
    if ($type eq 'SCALAR') {
        my $x = $$x;
        my $y = $$y;
        return compareR($x, $y, $reason_holder);
    }
    if ($type eq 'GLOB') {
        $reason_holder->[0]= "we consider ref objects to be different";
        return 0;
    }
    if ($type eq 'CODE') {
        return 1;       #changed for log4perl, let's just accept coderefs
    }
    croak "Can't handle $type type.";
}

1;
