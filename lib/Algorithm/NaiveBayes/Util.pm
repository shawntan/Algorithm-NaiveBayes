package Algorithm::NaiveBayes::Util;

use strict;
use base qw(Exporter);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(sum_hash max add_hash rescale);

sub sum_hash {
  my $href = shift;
  my $total = 0;
  $total += $_ foreach values %$href;
  return $total;
}

sub max {
  return undef unless @_;
  my $max = shift;
  foreach (@_) {
    $max = $_ if $_ > $max;
  }
  return $max;
}

sub add_hash {
  my ($first, $second) = @_;
  foreach my $k (keys %$second) {
    $first->{$k} += $second->{$k};
  }
}

sub rescale {
  my ($scores) = @_;

  # Scale everything back to a reasonable area in logspace (near zero), un-loggify, and normalize
  my $total = 0;
  my $max = max(values %$scores);
  foreach (values %$scores) {
    $_ = exp($_ - $max);
    $total += $_**2;
  }
  $total = sqrt($total);
  foreach (values %$scores) {
    $_ /= $total;
  }
}

1;
