package Algorithm::NaiveBayes;

$VERSION = '0.02';
use strict;

sub new {
  my $package = shift;
  return bless {
		purge => 1,
		@_,
		instances => 0,
		attributes => {},
		labels => {},
	       }, $package;
}

sub add_instance {
  my ($self, %params) = @_;
  for ('attributes', 'label') {
    die "Missing required '$_' parameter" unless exists $params{$_};
  }
  for ($params{label}) {
    $_ = [$_] unless ref;
  }
  
  $self->{instances}++;
  
  $self->_add_hash($self->{attributes}, $params{attributes});
  
  foreach my $label ( @{ $params{label} } ) {
    $self->{labels}{$label}{count}++;
    $self->{labels}{$label}{attributes} ||= {};
    $self->_add_hash($self->{labels}{$label}{attributes}, $params{attributes});
  }
}

sub _add_hash {
  my ($self, $first, $second) = @_;
  foreach my $k (keys %$second) {
    $first->{$k} += $second->{$k};
  }
}

sub _sum {
  my $href = shift;
  my $total = 0;
  $total += $_ foreach values %$href;
  return $total;
}

sub labels {
  my $self = shift;
  return keys %{ $self->{labels} };
}

sub train {
  my $self = shift;
  my $m = $self->{model} = {};
  
  my $vocab_size = keys %{ $self->{attributes} };
  
  # Calculate the log-probabilities for each category
  foreach my $label ($self->labels) {
    $m->{prior_probs}{$label} = log($self->{labels}{$label}{count} / $self->{instances});
    
    # Count the number of tokens in this cat
    my $label_tokens = _sum($self->{labels}{$label}{attributes});
    
    # Compute a smoothing term so P(word|cat)==0 can be avoided
    $m->{smoother}{$label} = -log($label_tokens + $vocab_size);
    
    my $denominator = log($label_tokens + $vocab_size);
    
    while (my ($attribute, $count) = each %{ $self->{labels}{$label}{attributes} }) {
      $m->{probs}{$label}{$attribute} = log($count + 1) - $denominator;
    }
  }
  $self->do_purge if $self->purge;
}

sub do_purge {
  my $self = shift;
  foreach (values %{ $self->{labels} }) {
    $_ = 1;
  }
}

sub purge {
  my $self = shift;
  $self->{purge} = shift if @_;
  return $self->{purge};
}

sub predict {
  my ($self, %params) = @_;
  my $newattrs = $params{attributes} or die "Missing 'attributes' parameter for predict()";
  my $m = $self->{model};  # For convenience
  
  # Note that we're using the log(prob) here.  That's why we add instead of multiply.
  
  my %scores;
  while (my ($label, $attributes) = each %{$m->{probs}}) {
    $scores{$label} = $m->{prior_probs}{$label}; # P($label)
    
    while (my ($feature, $value) = each %$newattrs) {
      next unless exists $self->{attributes}{$feature};
      $scores{$label} += ($attributes->{$feature} || $m->{smoother}{$label})*$value;   # P($feature|$label)**$value
    }
  }
  
  $self->_rescale(\%scores);
  return \%scores;
}

sub _rescale {
  my ($self, $scores) = @_;

  # Scale everything back to a reasonable area in logspace (near zero), un-loggify, and normalize
  my $total = 0;
  my $max = _max(values %$scores);
  foreach (values %$scores) {
    $_ = exp($_ - $max);
    $total += $_**2;
  }
  $total = sqrt($total);
  foreach (values %$scores) {
    $_ /= $total;
  }
}

sub _max {
  return undef unless @_;
  my $max = shift;
  foreach (@_) {
    $max = $_ if $_ > $max;
  }
  return $max;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Algorithm::NaiveBayes - Bayesian prediction of categories

=head1 SYNOPSIS

  use Algorithm::NaiveBayes;
  my $nb = Algorithm::NaiveBayes->new;

  $nb->add_instance
    (attributes => {foo => 1, bar => 1, baz => 3},
     label => 'sports');
  
  $nb->add_instance
    (attributes => {foo => 2, blurp => 1},
     label => ['sports', 'finance']);

  ... repeat for several more instances, then:
  $nb->train;
  
  # Find results for unseen instances
  my $result = $nb->predict
    (attributes => {bar => 3, blurp => 2});


=head1 DESCRIPTION

This module implements the classic "Naive Bayes" machine learning
algorithm.  It is a well-studied probabilistic algorithm often used in
automatic text categorization.  Compared to other algorithms (kNN,
SVM, Decision Trees), it's pretty fast and reasonably competitive in
the quality of its results.

A paper by Fabrizio Sebastiani provides a really good introduction to
text categorization:
L<http://faure.iei.pi.cnr.it/~fabrizio/Publications/ACMCS02.pdf>

=head1 METHODS

=over 4

=item new()

Creates a new C<Algorithm::NaiveBayes> object and returns it.  The
following parameters are accepted:

=over 4

=item purge

If set to a true value, the C<do_purge()> method will be invoked during
C<train()>.  The default is true.  Set this to a false value if you'd
like to be able to add additional instances after training and then
call C<train()> again.

=back

=item add_instance( attributes =E<gt> HASH, label =E<gt> STRING|ARRAY )

Adds a training instance to the categorizer.  The C<attributes>
parameter contains a hash reference whose keys are string attributes
and whose values are the weights of those attributes.  For instance,
if you're categorizing text documents, the attributes might be the
words of the document, and the weights might be the number of times
each word occurs in the document.

The C<label> parameter can contain a single string or an array of
strings, with each string representing a label for this instance.  The
labels can be any arbitrary strings.  To indicate that a document has no
applicable labels, pass an empty array reference.

=item train()

Calculates the probabilities that will be necessary for categorization
using the C<predict()> method.

=item predict( attributes =E<gt> HASH )

Use this method to predict the label of an unknown instance.  The
attributes should be of the same format as you passed to
C<add_instance()>.  C<predict()> returns a hash reference whose keys
are the names of labels, and whose values are the score for each
label.  Scores are between 0 and 1, where 0 means the label doesn't
seem to apply to this instance, and 1 means it does.

In practice, scores using Naive Bayes tend to be very close to 0 or 1
because of the way normalization is performed.  I might try to
alleviate this in future versions of the code.

=item labels()

Returns a list of all the labels the object knows about (in no
particular order), or the number of labels if called in a scalar
context.

=item do_purge()

Purges training instances and their associated information from the
NaiveBayes object.  This can save memory after training.

=item purge()

Returns true or false depending on the value of the object's C<purge>
property.  An optional boolean argument sets the property.

=back

=head1 THEORY

Bayes' Theorem is a way of inverting a conditional probability. It
states:

                P(y|x) P(x)
      P(x|y) = -------------
                   P(y)

The notation C<P(x|y)> means "the probability of C<x> given C<y>."  See also
L<"http://mathforum.org/dr.math/problems/battisfore.03.22.99.html">
for a simple but complete example of Bayes' Theorem.

In this case, we want to know the probability of a given category given a
certain string of words in a document, so we have:

                    P(words | cat) P(cat)
  P(cat | words) = --------------------
                           P(words)

We have applied Bayes' Theorem because C<P(cat | words)> is a difficult
quantity to compute directly, but C<P(words | cat)> and C<P(cat)> are accessible
(see below).

The greater the expression above, the greater the probability that the given
document belongs to the given category.  So we want to find the maximum
value.  We write this as

                                 P(words | cat) P(cat)
  Best category =   ArgMax      -----------------------
                   cat in cats          P(words)


Since C<P(words)> doesn't change over the range of categories, we can get rid
of it.  That's good, because we didn't want to have to compute these values
anyway.  So our new formula is:

  Best category =   ArgMax      P(words | cat) P(cat)
                   cat in cats

Finally, we note that if C<w1, w2, ... wn> are the words in the document,
then this expression is equivalent to:

  Best category =   ArgMax      P(w1|cat)*P(w2|cat)*...*P(wn|cat)*P(cat)
                   cat in cats

That's the formula I use in my document categorization code.  The last
step is the only non-rigorous one in the derivation, and this is the
"naive" part of the Naive Bayes technique.  It assumes that the
probability of each word appearing in a document is unaffected by the
presence or absence of each other word in the document.  We assume
this even though we know this isn't true: for example, the word
"iodized" is far more likely to appear in a document that contains the
word "salt" than it is to appear in a document that contains the word
"subroutine".  Luckily, as it turns out, making this assumption even
when it isn't true may have little effect on our results, as the
following paper by Pedro Domingos argues:
L<"http://www.cs.washington.edu/homes/pedrod/mlj97.ps.gz">


=head1 HISTORY

My first implementation of a Naive Bayes algorithm was in the
now-obsolete AI::Categorize module, first released in May 2001.  I
replaced it with the Naive Bayes implementation in AI::Categorizer
(note the extra 'r'), first released in July 2002.  I then extracted
that implementation into its own module that could be used outside the
framework, and that's what you see here.

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 SEE ALSO

AI::Categorizer(3), L<perl>.

=cut