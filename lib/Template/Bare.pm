# Template::Bare - version 0.02
package Template::Bare;
# Originally based off Text::Template Version 1.46
# Changes from Text::Template: Removed 'safe' option, ability to use template sources other than a plain string,
#   'prepend' option, custom delimiters, and $ERROR variable. Mercilessly removed anything that is not absolutely
#   needed for basic processing of text templates

use Exporter;
use Carp;
@ISA = qw(Exporter);
@EXPORT_OK = qw(fill_in_string tpl_to_chunks create_delayed fill_in_delayed);
use strict;
$Template::Bare::VERSION = '0.01';
sub new { my $pkg = shift; return bless { @_ }, $pkg; }

sub compile {
  my $self = shift;
  my @tokens = split /(\\\\(?=\\*[{}])|\\[{}]|[{}\n])/, $self->{'source'};
  my $state = 0;# 0 is text, 1 is prog
  my $depth = 0;
  my $lineno = 1;
  my @content;
  my $cur_item = '';
  my $prog_start;
  
  for my $t ( @tokens ) {
    if( $t eq '{' ) {
      if( $depth == 0 ) {
        push( @content, [$state, $cur_item, $lineno] ) if $cur_item ne '';
        $cur_item = '';
        $state = 1;
        $prog_start = $lineno;
      }
      else { $cur_item .= $t; }
      $depth++;
    }
    elsif( $t eq '}' ) {
      $depth--;
      if( $depth < 0 ) { die "Unmatched close brace at line $lineno"; }
      elsif( $depth == 0 ) {
        push( @content, [$state, $cur_item, $prog_start] ) if $cur_item ne '';
        $state = 0;
        $cur_item = '';
      }
      else { $cur_item .= $t; }
    }
    elsif( $t eq "\n" ) {
      $lineno++;
      $cur_item .= $t;
    }
    else { $cur_item .= $t; }
  }
  
  if( $state==1 ) { confess "End of data in template at line $prog_start -- " . $self->{'source'}; }
  if( $state==0 ) { push( @content, [$state, $cur_item, $lineno] ) if $cur_item ne ''; }
  
  $self->{'source'} = \@content;
  return $self;
}

sub fill_in {
  my $self = shift;
  $self->write_hash( $self->{'hash'} );
  my $package = $self->{'package'};
  my $r = '';
  for my $item ( @{$self->{'source'}} ) {
    my ( $type, $text, $lineno ) = @$item;
    if( $type==0 ) { $r .= $text; next; }
    my $progtext = "package $package; #line $lineno\n$text;";
    no strict;
    my $OUT;
    my $res = eval $progtext;
    my $eval_err = $@;
    $res = $OUT if defined $OUT;
    if( $eval_err ) {
      print STDERR $self->{'origin'} . " Template error\n";
      chomp $eval_err;
      print STDERR "  Error: $eval_err\n";
      print STDERR "  template: $text\n";
      die;
    }
    if( ! defined $res ) {
      print STDERR "Template chunk evaluated to undefined: -- $text --\n";
    }
    $r .= $res;
  }
  return $r;
}

sub to_chunks {
  my $self = shift;
  $self->write_hash( $self->{'hash'} );
  my $package = $self->{'package'};
  my @chunks;
  for my $item ( @{$self->{'source'}} ) {
    my ( $type, $text, $lineno ) = @$item;
    if( $type==0 ) { push( @chunks, [ 0, $text ] ); next; }
    if( $text =~ m/^\:/ ) {
      $text = substr( $text, 1 );
      my @parts = split( ':', $text );
      my @out;
      for my $part ( @parts ) {
        if( $part =~ m/^\{(.+)\}$/ ) {
          no strict;
          my $OUT;
          my $progtext = "package $package; #line $lineno\n$part;";
          my $res = eval $progtext;
          my $eval_err = $@;
          $res = $OUT if defined $OUT;
          die $self->{'origin'} . " - Template error ``$eval_err''" if( $eval_err );     
          push( @out, $res );
        }
        else {
          push( @out, $part );
        }
      }
      push( @chunks, [ 1, \@out ] );
    }
    else {
      my $progtext = "package $package; #line $lineno\n$text;";
      no strict;
      my $OUT;
      my $res = eval $progtext;
      my $eval_err = $@;
      $res = $OUT if defined $OUT;
      die $self->{'origin'} . " - Template error ``$eval_err''" if( $eval_err );     
      push( @chunks, [ 0, $res ] );
    }
  }
  return \@chunks;
}

sub write_hash {
  my ( $self, $hash ) = @_;
  my $package = $self->{'package'};
  for my $name ( keys %$hash ) {
    my $val = $hash->{$name};
    no strict 'refs';
    local *SYM = *{"${package}::$name"};
    if( ! defined $val ) { delete ${"${package}::"}{$name}; } 
    elsif( ref $val    ) { *SYM = $val; } 
    else                 { *SYM = \$val; }
  }
}

sub tpl_to_chunks {
  my ( $string, $hash, $package, $more ) = @_;
  my ( $op, $of, $ol ) = caller; $more ||= '';
  return Template::Bare->new( source => $string, hash => $hash, package => $package, origin => "$of - $ol - $more" )->compile()->to_chunks();
}

sub fill_in_string {
  my ( $string, $hash, $package, $more ) = @_;
  my ( $op, $of, $ol ) = caller; $more ||= '';
  return Template::Bare->new( source => $string, hash => $hash, package => $package, origin => "$of - $ol - $more" )->compile()->fill_in();
}

sub create_delayed {
  my ( $string, $hash, $package, $more ) = @_;
  $more ||= '';
  my $clone = weak_clone( $hash );
  return { str => $string, hash => $clone, package => $package, more => $more };
}

sub weak_clone {
  my $hash = shift;
  my %dup;
  for my $key ( keys %$hash ) {
    $dup{ $key } = $hash->{ $key };
  }
  if( $hash->{'byname'} ) {
    $dup{'byname'} = weak_clone( $hash->{'byname'} );
  }
  return \%dup;
}

sub fill_in_delayed {
  my ( $object, $hash_more ) = @_;
  my ( $op, $of, $ol ) = caller;
  my $string = $object->{'str'};
  my $hash = $object->{'hash'};
  my $package = $object->{'package'};
  my $more = $object->{'more'};
  $hash = { %$hash, %$hash_more };
  $hash->{'ctx'} = $hash;
  return Template::Bare->new( source => $string, hash => $hash, package => $package, origin => "$of - $ol - $more" )->compile()->fill_in();
}
1;