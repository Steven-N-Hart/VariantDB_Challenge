#!/usr/bin/perl

use List::Util qw(sum);
####################
## SET THRESHOLDS ##
####################
$savant_regex = "MODERATE|HIGH";
$min_total_depth = 30;
$min_alt_depth = 10;
$min_gq = 30;
$max_af = 0.1;
# then : heterozygous, per population excluding some samples.

#############################
# read in cryptic relations.#
#############################
my %cryptic = ();
if (!-s "README.sample_cryptic_relations") {
	system("wget -q -O 'README.sample_cryptic_relations' 'ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/release/20110521/README.sample_cryptic_relations'");
}
open IN, "README.sample_cryptic_relations";
my $line = <IN>;
while ($line !~ m/^Population/) {
	$line = <IN>;
}
while (<IN>) {
	chomp;
	my @p = split(/\t/,$_)	;
	if ($p[0] ne 'ASW' || $p[3] ne 'Sibling') {
		$cryptic{$p[1]} = 1;
		$cryptic{$p[2]} = 1;
	}
}
close IN;
################################
# read in population structure.#
################################
if (!-s "phase1_integrated_calls.20101123.ALL.panel") {
	system("wget -q -O 'phase1_integrated_calls.20101123.ALL.panel' 'ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/release/20110521/phase1_integrated_calls.20101123.ALL.panel'");
}
open IN, "phase1_integrated_calls.20101123.ALL.panel";
my %pop = ();
while (<IN>) {
	chomp;
	my @c = split(/\t/,$_);
	if (!defined($cryptic{$c[0]})) {
		$pop{$c[0]} = $c[2];
	}
	
}
my %counts = ();
foreach(values(%pop)) {
	$counts{$_} = 0;
}
$|++;

###################
## SCAN VCF FILE ##
###################
if (!-s "input.vcf") {
	system("wget -q -O 'input.vcf.gz' 'https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/vcfs/1KG.chr22.anno.infocol.vcf.gz'");
	if (!-s 'input.vcf.gz') {
		die("Could not download VCF file.\n");
	}
	system("gunzip input.vcf.gz");
}

open IN, "input.vcf";
my $line = <IN>;
while ($line !~ m/^#CHROM/){ 
	$line = <IN>;
}
chomp($line);
my @headers = split(/\t/,$line);
my $cidx = -1;
my %header_list = ();
foreach(@headers) {
	$cidx++;
	$header_list{$_} = $cidx;
}
my $lidx = 0;
$passing = 0;
my %seen = ();
while (<IN>) {
	$lidx++;
	chomp;
	my @c = split(/\t/,$_);
	# VCF contains doubles (same variant on multiple lines. 
	if (defined($seen{$c[0]."-".$c[1]."-".$c[3]."-".$c[4]})) {
		$seen{$c[0]."-".$c[1]."-".$c[3]."-".$c[4]}++;
		next;
	}
	$seen{$c[0]."-".$c[1]."-".$c[3]."-".$c[4]} = 1;
	# match savant
	my $savant = '';
	if($c[7] !~ m/SAVANT_IMPACT=($savant_regex);/) {
		$savant = '.';
		next;
	}
	else {
		$savant = $1;
	}
	my $af = '-1';
	my @info = split(/;/,$c[7]);
	foreach my $f (@info) {
		if ($f =~ m/ExAC.Info.AF=(.*)/) {
			$af = $1;
			last;
		}
	}
	if ($af >= $max_af) {
		next;
	}
	# scan format.
	my @f = split(/:/,$c[8]);
	my $fidx = -1;
	my %fh = ();
	foreach(@f) {
		$fidx++;
		$fh{$_} = $fidx;
	}
	# loop samples.
	for (my $i = 9; $i< scalar(@c); $i++) {
		if (!defined($pop{$headers[$i]})) {
			next;
		}
		my @s = split(/:/,$c[$i]);
		# GQ: skip if not set or less than treshold.
		if ($s[$fh{'GQ'}] eq '.' || $s[$fh{'GQ'}] <= $min_gq) {
			next;
		}
		# GT : skip if both alleles are identical (homozygous call)
		my @gt = split(/\/|\|/,$s[$fh{'GT'}]);
		if ($gt[0] eq $gt[1]) {
			next;
		}
		# Alt_Depth : skip if less than treshold or not set.
		my @ad = split(/,/,$s[$fh{'AD'}]);
		if (scalar(@ad) < 2 || $ad[1] <= $min_alt_depth) {
			next;
		}
		# total depth: skip if sum of ADs is less than treshold. (DP should not be greater than sum(AD) according to it's definition...)
		my $t_depth = my $sum_ad = -1;
		if (scalar(@ad) > 1) {
			# total sum of AD (if specified)
			$sum_ad = sum(@ad);
		}
		#if (defined($s[$fh{'DP'}]) &&  $s[$fh{'DP'}] ne '.') {
		#	# total Depth in DP field (if specified)
		#	$t_depth = $s[$fh{'DP'}];
		#}
		if ($sum_ad <= $min_total_depth ) {#&& $t_depth <= $min_total_depth) {
			next;
		}
		$passing++;
		# ok ! print sample and values.
		print "PASS: line $lidx : $c[0]:$c[1] : $c[3]/$c[4] : $headers[$i] : $pop{$headers[$i]} : Savant: $savant ; AF: $af ; GQ: $s[$fh{'GQ'}] ; GT: $s[$fh{'GT'}] ; AD: $s[$fh{'AD'}] ; DP: $s[$fh{'DP'}] \n";
		$counts{$pop{$headers[$i]}}++
	}
}
close IN;
##################
## PRINT RESULT ##
##################
#print "The following variants were present in the VCF multiple times, and were skipped:\n";
#foreach(sort {$seen{$b} <=> $seen{$a} } keys(%seen)) {
#
#	if ($seen{$_} > 1) {
#		print "  - $_ : $seen{$_}x\n";
#	}
#	else {
#		last;
#	}
#}
print "\n";
print "Total passing variants: $passing\n";
print "Passing variants by population:\n";
foreach(keys(%counts)) {
	print "  $_ : $counts{$_}\n";
}


