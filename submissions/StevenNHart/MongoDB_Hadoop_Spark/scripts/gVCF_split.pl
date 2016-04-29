#!/usr/bin/env perl
##fix
# Split the multi-allelic sites in a VCF onto multiple rows, one alt allele per row
# Jared Evans evans.jared@mayo.edu
# 10/2014
# David Rider
# 07/2016
# Add the option to supply your own INFO keys on the command line to use for splitting 

use strict;
#use warnings;
#use Data::Dumper;
use Getopt::Long;

my @DEFAULT_INFO_KEYS_TO_SPLIT = qw(AC AF TAC EA_AC AA_AC AC_AFR AC_AMR AC_Adj AC_EAS AC_FIN AC_Hemi AC_Het AC_Hom AC_NFE AC_OTH AC_SAS AN AN_AFR AN_AMR AN_Adj AN_EAS AN_FIN AN_NFE AN_OTH AN_SAS GQ_MEAN Het_AFR Het_AMR Het_EAS Het_FIN Het_NFE Het_OTH Het_SAS Hom_AFR Hom_AMR Hom_EAS Hom_FIN Hom_NFE Hom_OTH Hom_SAS MLEAC Hemi_AFR Hemi_AMR Hemi_EAS Hemi_FIN Hemi_NFE Hemi_OTH Hemi_SAS);

# script options
my($input, $output, $info_keys_to_split_delimited, $help);
GetOptions("in|i:s"     => \$input,
        "out|o:s"       => \$output,
        "keys|k:s"       => \$info_keys_to_split_delimited,
        "help|h|?"     => \&help);

# read from input file if defined
@ARGV = ();
if(defined $input){
	$ARGV[0] = $input;
}

# print to output file if defined
my $fh;
if (defined $output) {
	open $fh, '>', $output;
	select $fh;
}

my @info_keys_to_split = @DEFAULT_INFO_KEYS_TO_SPLIT;
if (defined $info_keys_to_split_delimited) {
	@info_keys_to_split = split(/,/, $info_keys_to_split_delimited);
}
# David Rider - create this to actually check if a key is in the list of keys for splitting - see below
my %info_keys_to_split_map = map { $_ => 1 } @info_keys_to_split;

my $sample_count = 0;

while(<>){
	my $row = $_;
	chomp $row;
	my @line = split("\t",$row);
	# deal with header
	if(substr($line[0],0,1) eq "#"){
		if($line[0] eq "#CHROM"){
			# Samples begin at column 10
			$sample_count = scalar(@line)-9;
			#die("ERROR! No sample information in VCF\n") if $sample_count <= 0;
			if ($sample_count <= 0){$row=$row."\tFORMAT\tSAMPLE"}
		}
		print $row."\n";
		next;
	}
	
	# parse INFO field
	my %info_values = ();
	my @info_keys = ();
	foreach my $info_pair (split(";",$line[7])){
		my @key_value = split("=",$info_pair);
		push(@info_keys,$key_value[0]);
		if(scalar(@key_value) > 1){
			$info_values{$key_value[0]} = join("=",@key_value[1..(scalar(@key_value)-1)]);
		} 
	}

	# reformat sample columns and print output
	my @alt_alleles = split(",",$line[4]);
	# split multiple alt alleles onto seperate lines
	for(my $split_rownum = 0; $split_rownum < scalar(@alt_alleles); $split_rownum++){ 
		next if (($alt_alleles[$split_rownum] eq "<NON_REF>")&& ($split_rownum > 0));
		print join("\t",@line[0..3])."\t".$alt_alleles[$split_rownum]."\t".join("\t",@line[5..6])."\t";
		
		# print out INFO fields
		for(my $j = 0; $j < scalar(@info_keys); $j++){
			if(exists $info_values{$info_keys[$j]}){
				# these have comma seperated values for each alt allele
                                # check this key against the list of INFO keys to split
				if(exists($info_keys_to_split_map{$info_keys[$j]})){
					my @alt_info_values = split(",",$info_values{$info_keys[$j]});
					if(scalar(@alt_info_values) > 1){
						print $info_keys[$j]."=".$alt_info_values[$split_rownum];
					}else{
						print $info_keys[$j]."=".$alt_info_values[0];
					}
				}else{
					print $info_keys[$j]."=".$info_values{$info_keys[$j]};
				}
			}else{
				print $info_keys[$j];
			}
			print ";" if $j < scalar(@info_keys)-1; # only put semicolon between values
		}
		
		# Get FORMAT values
		my @format_values = split(":",$line[8]);
		if (!$line[8]){$line[8]="GT"}
		print "\t".$line[8];
		
		# print SAMPLE columns
		for(my $sample_num = 0; $sample_num < $sample_count; $sample_num++){
			print "\t";
			my @sample_fields = split(":",$line[9+$sample_num]);
			# special cases for each type of format value
			for(my $field_num = 0; $field_num < scalar(@sample_fields); $field_num++){
				my $output = "";
				if($sample_fields[$field_num] eq "."){
					$output = $sample_fields[$field_num];
				}elsif($format_values[$field_num] eq "GT"){
					my $separator = "/";
					$separator = "|" if index($sample_fields[$field_num],"|") != -1; # check if GT is phased
					my @gt_index = ();
					if($separator eq "|"){
						# escape the | symbol so it doesnt interpret as OR
						@gt_index = split("\\".$separator,$sample_fields[$field_num]);
					}else{
						@gt_index = split($separator,$sample_fields[$field_num]);
					}
					my $ploidy = scalar(@gt_index);
					# initialize GT output array
					my @gt_out = ();
					for(my $i = 0; $i < $ploidy; $i++){
						push(@gt_out,".");
					}
					
					for(my $gt_ind = 0; $gt_ind < $ploidy; $gt_ind++){
						if($gt_index[$gt_ind] ne "."){
							if($gt_index[$gt_ind] == $split_rownum+1){
								$gt_out[$gt_ind] = 1;
							}elsif($gt_index[$gt_ind] == 0){
								$gt_out[$gt_ind] = 0;
							}
						}
					}

					# don't sort the GTs if phased
					if($separator eq "|"){
						$output = join($separator,@gt_out);
					}else{
						$output = join($separator,sort(@gt_out));
					}

				}elsif($format_values[$field_num] eq "AD"){
					my @ad = split(",",$sample_fields[$field_num]);
					#ats Accomodate the 0/. GT value where only 1 AD value is present.  Normally multiple exist.
					if(scalar(@ad) == 1) {
						$output = $ad[0];
					}else{
						$output = $ad[0].",".$ad[$split_rownum+1];
					}
				}elsif($format_values[$field_num] eq "GL" or $format_values[$field_num] eq "PL" or $format_values[$field_num] eq "GP"){
					my @lk = split(",",$sample_fields[$field_num]);
					# formula for finding correct GL or PL: F(j/k) = (k*(k+1)/2)+j
					$output = $lk[0].",".$lk[((($split_rownum+1)*($split_rownum+2)/2)+0)].",".$lk[((($split_rownum+1)*($split_rownum+2)/2)+$split_rownum+1)];
				}elsif($format_values[$field_num] eq "DP4"){
					my @dp4 = split(",",$sample_fields[$field_num]);
					$output = $dp4[0].",".$dp4[1].",".$dp4[($split_rownum+1)*2].",".$dp4[(($split_rownum+1)*2)+1];
				}else{
					$output = $sample_fields[$field_num];
				}

				# print output
				if($field_num == 0){
					print $output;
				}else{
					print ":".$output;
				}
			}
		}
		if (!$line[9]){print "\t0/1"}
		print "\n";
	}
}

	
sub help{

        my $default_info_key_str = join(',', @DEFAULT_INFO_KEYS_TO_SPLIT);

        print "
DESCRIPTION:
        split_multi_vcf.pl will split triallelic and greater sites onto multiple lines ensuring 
        that each row only has one Alt allele. The script will also fix the necessary INFO and 
        FORMAT values to preserve valid VCF format.

USAGE:
        split_multi_vcf.pl -i input.vcf -o output_split.vcf
        cat input.vcf | split_multi_vcf.pl > output_split.vcf

OPTIONS:
        --in,-i         Optional path to uncompressed input VCF file with multi-allelic sites. 
                        If this option is omitted then the script will read from STDIN.

        --out,-o        Optional path to output VCF file. If this option is omitted then the 
                        script will print to STDOUT.

        --keys,-k       Supply the list of comma-delimited keys to split in the INFO field. 
                        By default, the list of keys come from the ExAC VCF and are 
                        $default_info_key_str

        --help,-h,-?    Display this help documentation.

";
exit;
}
