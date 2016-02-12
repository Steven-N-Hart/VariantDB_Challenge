#!/usr/bin/perl -w
use Getopt::Long;

#Initialize values
my ($qual);
GetOptions ("qual|q=i" => \$qual);

if(!$qual){$qual=20}

open(VCF,"$ARGV[0]") or die "must specify VCF file\n\n";
while (<VCF>) {
	if($_=~/^#/){print;next}
  my @line=split("\t",$_);
  my @FORMATS=split(":",$line[8]);
  my ( $index ) = grep {$FORMATS[$_] eq "GQ"} 0..$#FORMATS;
  @SAMPLE = split(":",$line[9]);
  next if (!$index);
  next if($SAMPLE[$index] =~/^\.$/);
  if($SAMPLE[$index] > $qual){
    print;
  }
}

close VCF;
