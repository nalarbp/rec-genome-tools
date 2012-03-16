#!/usr/bin/perl

# Summary:
# This script produces a histogram of how many hits there are within 
# a given expectation value cutoff, scaled by the total number of 
# genes in both species 
#
# Calculate mean number of hits per gene = (H1+H2)/(N1+N2)
# where H1 and H2 are the number of hits in the two directions 
# and N1 and N2 are the number of genes in each species. 
# and where both have E < E0.
#
# It also produces a histogram for each species, of how many 
# genes do not register a hit with respect to an expectation value 
# cutoff, scaled by the total number of query genes

use strict;

# math function

use POSIX qw(ceil);
my $lg10=log(10);

# check to make sure that the program was given the correct number
# of input args 

if (scalar(@ARGV) != 5) {
  die("input arguments:\n 2 refseq identifiers (genomes to compare), \n an expectation cutoff, \n a length fraction (if it is 0 this isn't used), \n a flag to set the length fraction match to the long or short gene, \neg. ./hits_analyzer.pl NC_123 NC_456 1e-3 0.25 long \n");
}

# read in the first ID and make sure it is of the proper format

my $id1;
if ($ARGV[0] =~ /\D{2}\_\d+.*/) {
    $id1 = $ARGV[0];
} else {
    die("failed to understand input argument 1: ", $ARGV[0], "\n");
}

# read in the second ID and make sure it is of the proper format

my $id2;
if ($ARGV[1] =~ /\D{2}\_\d+.*/) {
    $id2 = $ARGV[1];
} else {
    die("failed to understand input argument 2: ", $ARGV[1], "\n");
}

# read in the E cutoff

my $e_cutoff;
if ($ARGV[2] =~ /\D.*\.?e?\D.*/) {
  $e_cutoff = $ARGV[2];
} else {
  die("failed to understand input argument 3: ",$ARGV[2], "\n");
}

# read in the length fraction

my $mlf;
my $mlf_type;
if ($ARGV[3] =~ /\d*\.?\d*/) {
  $mlf = $ARGV[3];
  if ($mlf == 0.0) {
    $mlf_type = 0;
  } else {
    # read in the lfm type
    if ($ARGV[4] =~ /short/) {
      $mlf_type = 1;
    } else {
      if ($ARGV[4] =~ /long/) {
        $mlf_type = 2;
      } else { 
        die("failed to understand input argument 5: ",$ARGV[4], "\n");
      }
    }
  }
} else {
  die("failed to understand input argument 4: ",$ARGV[3], "\n");
}

# open the fasta file to determine how many sequences there are 
# in each species

my $NG1=0;
open(SF1,"<$id1.faa") || die("couldn't open file $id1.faa\n");
while (<SF1>) {
  if ($_ =~ /^>gi\|\d+\|ref\|.*/) {
    $NG1++;
  }
}
close(SF1);
#print "number of genes in $id1= $NG1\n";

my $NG2=0;
open(SF2,"<$id2.faa") || die("couldn't open file $id2.faa\n");
while (<SF2>) {
  if ($_ =~ /^>gi\|\d+\|ref\|.*/) {
    $NG2++;
  }
}
close(SF2);
#print "number of genes in $id2= $NG2\n";

my $total_genes=$NG1+$NG2;

# open the significant hits files that were generated by 
# hit_extractor_verbose.pl and read each line into a string 
# that is stored in an array 
# 
# at present each line is of the form:
# refseq_query_id refseq_hit_id significance mlf_short mlf_long
#
# eg.
# NP_012345.1 NP_6789.2 1.35e-32 0.23 0.11
#
# the filename is ordered in the opposite direction though,
# Genome_Database.Genome_Queries.hits

my ($hit,$query_id,$hit_id,$e_val,$mlfs,$mlfl);

open(IF1, "<$id1.$id2.hits") || die("couldn't open file $id1.$id2.hits\n");
my(@th1) = <IF1>;
close(IF1);


# this is the listing of genome $id2 queries 
my %hoh1 = ();
foreach $hit(@th1) {
     chomp($hit);
     ($query_id,$hit_id,$e_val,$mlfs,$mlfl)=split(/\ /,$hit);
# build a hash of hashes
     if ( $e_val < $e_cutoff ) {
        if ( $mlf_type == 0 ) {
          $hoh1{ $query_id }{ $hit_id } = $e_val;
        } else {
          if (( $mlf_type == 1 ) && ( $mlfs > $mlf )) {
            $hoh1{ $query_id }{ $hit_id } = $e_val;
          } else { 
            if (( $mlf_type == 2 ) && ( $mlfl > $mlf )) {
              $hoh1{ $query_id }{ $hit_id } = $e_val;
            }
          } 
        }
     }
}

open(IF2, "<$id2.$id1.hits") || die("couldn't open file $id2.$id1.hits\n");
my(@th2) = <IF2>;
close(IF2);

my %hoh2 = ();
foreach $hit(@th2) {
     chomp($hit);
     ($query_id,$hit_id,$e_val,$mlfs,$mlfl)=split(/\ /,$hit);
# build a hash of hashes
     if ( $e_val < $e_cutoff ) {
        if ( $mlf_type == 0 ) {
          $hoh2{ $query_id }{ $hit_id } = $e_val;
        } else {
          if (( $mlf_type == 1 ) && ( $mlfs > $mlf )) {
            $hoh2{ $query_id }{ $hit_id } = $e_val;
          } else { 
            if (( $mlf_type == 2 ) && ( $mlfl > $mlf )) {
              $hoh2{ $query_id }{ $hit_id } = $e_val;
            }
          } 
        }
     }
}

# open a new file, to be overwritten (not appended), to store the
# a) expectation threshold
# a) number of hits / total genes
# b) number of genes from genome 1 without a hit in genome 2 / total genes in genome 1 
# b) number of genes from genome 2 without a hit in genome 1 / total genes in genome 2

open(OF, ">$id2.$id1.E_hits"); 

# working on hash of hashes:
#
#while( my $k = each %hoh1) {
#      print "key: $k\n";
#      while( my $ke = each %{$hoh1{ $k }} ) {
#          print "   key: $ke\n";
#      }
#}
## sort is optional below
#foreach my $k1 ( sort keys %hoh1 ) {
#  foreach my $k2 ( sort keys %{$hoh1{$k1}} ) {
#      print "$k1\t$k2\t$hoh1{$k1}{$k2}\n";
#  }
#}
# ----------------------- HERE --------------------------------

my @hist;
my @hist_1;
my @hist_2;
my @histr;

# to calculate exponent (round down)
#  $j=floor((log($i))/$lg10);
#
# WRONG!!! We actually want to round up to the 
# next highest exponent -- smaller expectation
# is more significant, so:
# $j=ceil((log($i))/$lg10);
#
#  we want this to be an array index
#  runs from -~400:2
#  add 400?
#
# for (my $ii = 0; $ii <=402; $ii++) {
#   @hist[$ii]=0;
# }
#
# now we want more resolution around 0
# so we need to bin more finely - decrease
# bin size by an order of magnitude

for (my $ii = 0; $ii <=4020; $ii++) {
   @hist[$ii]=0;
   @hist_1[$ii]=0;
   @hist_2[$ii]=0;
   @histr[$ii]=0;
}

my ($k1, $k2, $highest_e, $lowest_e);

# find top hits in genome 1 and populate hist_1
# with queries from genome 2

foreach $k1 ( keys %hoh1 ) {
    $lowest_e = 10.0;
    foreach $k2 ( keys %{$hoh1{$k1}} ) {
        if ( $hoh1{$k1}{$k2} < $lowest_e ) {
            $lowest_e = $hoh1{$k1}{$k2}
        }
    }
    if ($lowest_e == 0) {
        @hist_1[0]++;
    } else {
        @hist_1[4000+ceil(10*(log($lowest_e))/$lg10)]++;
    }
}

# find top hits in genome 2 and populate hist_2
# with queries from genome 1

foreach $k1 ( keys %hoh2 ) {
    $lowest_e = 10.0;
    foreach $k2 ( keys %{$hoh2{$k1}} ) {
        if ( $hoh2{$k1}{$k2} < $lowest_e ) {
            $lowest_e = $hoh2{$k1}{$k2}
        }
    }
    if ($lowest_e == 0) {
        @hist_2[0]++;
    } else {
        @hist_2[4000+ceil(10*(log($lowest_e))/$lg10)]++;
    }
}

## loop over queries in report to find reciprocal
## hits

foreach $k1 ( keys %hoh1 ) {
    foreach $k2 ( keys %{$hoh1{$k1}} ) {
        if ( exists $hoh2{$k2}{$k1} ) {
            if ( $hoh2{$k2}{$k1} > $hoh1{$k1}{$k2} ) {
                $highest_e = $hoh2{$k2}{$k1};
            } else {
                $highest_e = $hoh1{$k1}{$k2};
            }
            if ($highest_e == 0) {
                @histr[0]++;
            } else {
                @histr[4000+ceil(10*(log($highest_e))/$lg10)]++;
            }
        }
    }
}

# loop over queries in both reports to find total
# hits

foreach $k1 ( keys %hoh1 ) {
    foreach $k2 ( keys %{$hoh1{$k1}} ) {
        $highest_e = $hoh1{$k1}{$k2};
        if ($highest_e == 0) {
            @hist[0]++;
        } else {
            @hist[4000+ceil(10*(log($highest_e))/$lg10)]++;
        }
    }
}
foreach $k1 ( keys %hoh2 ) {
    foreach $k2 ( keys %{$hoh2{$k1}} ) {
        $highest_e = $hoh2{$k1}{$k2};
        if ($highest_e == 0) {
            @hist[0]++;
        } else {
            @hist[4000+ceil(10*(log($highest_e))/$lg10)]++;
        }
    }
}

my $array_total=0;
my $array_total_r=0;
my $array_total_1=0;
my $array_total_2=0;
$array_total += $_ foreach @hist;
$array_total_1 += $_ foreach @hist_1;
$array_total_2 += $_ foreach @hist_2;
$array_total_r += $_ foreach @histr;
print "total number of hits in histogram = total: $array_total recip: $array_total_r not_in_1: $array_total_1 not_in_2: $array_total_2 \n";

my $start_ii;
# find the smallest expectation threshold (before 0) where
# there is still a hit: 
for (my $ii = 1; $ii <=4020; $ii++){
   if (( @hist[$ii] == 0 ) && ( @hist_1[$ii] == 0 ) && ( @hist_2[$ii] == 0 ) && ( @histr[$ii] == 0)) {
     next;
   } else { 
     $start_ii = $ii;
     last; 
   }
}

# loop over expectation values accumulating hits below 
# each threshold, running from 0->10 in logarithmic base 10
# increments
#
# divide by total number of genes in both genomes
my $fraction_tot_genes;
my $fraction_tot_genes_r;
# this is for sum of genes without hits
my $fraction_tot_genes_not;
# divide by number of genes in each genome
my $fraction_gen1;
my $fraction_gen2;

my $running_total += @hist[0];
my $running_total_r += @histr[0];
my $running_total_1 = $array_total_1 - @hist_1[0];
my $running_total_2 = $array_total_2 - @hist_2[0];
my $running_total_3 = $running_total_1 + $running_total_2;
$fraction_tot_genes = $running_total / $total_genes;
$fraction_tot_genes_r = $running_total_r / $total_genes;
$fraction_gen1 = $running_total_1 / $NG2;
$fraction_gen2 = $running_total_2 / $NG1;
$fraction_tot_genes_not = $running_total_3 / $total_genes;
print OF "0.0 $fraction_tot_genes $fraction_tot_genes_r $fraction_gen1 $fraction_gen2 $fraction_tot_genes_not\n";

my $cur_exp;
for ( my $ii = $start_ii; $ii <=4020; $ii++){
     $cur_exp = 10**(($ii - 4000) / 10); 
     $running_total += @hist[$ii];
     $running_total_r += @histr[$ii];
     $running_total_1 -= @hist_1[$ii];
     $running_total_2 -= @hist_2[$ii];
     $running_total_3 = $running_total_1 + $running_total_2;
     $fraction_tot_genes = $running_total / $total_genes;
     $fraction_tot_genes_r = $running_total_r / $total_genes;
     $fraction_gen1 = $running_total_1 / $NG2;
     $fraction_gen2 = $running_total_2 / $NG1;
     $fraction_tot_genes_not = $running_total_3 / $total_genes;
     print OF "$cur_exp $fraction_tot_genes $fraction_tot_genes_r $fraction_gen1 $fraction_gen2 $fraction_tot_genes_not\n";
}

# double check that we counted every hit

if ( $running_total != $array_total ) {
   print "Error! total hits accumulated should be $array_total, != $running_total\n";
}

if ( $running_total_r != $array_total_r ) {
   print "Error! total reciprocal hits accumulated should be $array_total_r, != $running_total_r\n";
}

if ( $running_total_1 != 0 ) {
   print "Error! total hits in genome 1 accumulated should be 0, != $running_total_1\n";
}

if ( $running_total_2 != 0 ) {
   print "Error! total hits in genome 2 accumulated should be 0, != $running_total_2\n";
}

close(OF);
