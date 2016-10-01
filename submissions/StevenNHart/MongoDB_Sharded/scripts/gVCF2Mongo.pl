#! /usr/bin/env perl

use Getopt::Long;
use Scalar::Util qw(looks_like_number);
#use Digest::MD5 qw(md5);

GetOptions ("VCF|v=s" => \$vcf,    # string
            "study|s=s"  => \$study,      # string
            "strict|z"  => \$strict,
            "biallele|b" => \$biallele,
            "kill|k=i" => \$kill, 
            "help|h"  => \$help);   # flag

#Create help and usage statement
sub help{
	print "Usage: perl VCF2Arango.pl -v <VCF_file> -s <study_name>
		Options:
				-strict|z 	overwrite existing jsons [default appends]
				-kill <int> 	kill after <int> rows
	\n\n";
	die;
}

#Create subroutine to validate inputs
sub validateInput{
   ($name,$value) = @_;
   if(!$value){
   	print "\n$name is not defined in your input\n\n";
   	help();
   	die 
   }
}

#Convert the format field to appropriate value
sub formatParse{
	#formatSchema is a ":" delimited grouping from teh VCF file
	#sampleFormat is the data from teh VCF that follows the formatSchema
	#keyName is the chrom:pos:ref:alt:study:sampleID
	my ($formatSchema,$sampleFormat,$study,$sampleID,$md5) = @_ ;
	next if ($md5=~/NON_REF/);
	#Convert the formatSchema and sampleFormat into array
	@formatSchema = split(":", $formatSchema);
	@sampleFormat =	split(":", $sampleFormat);
	#If the schema length and the sampleFormat are not the same size, then it cant be allowed to insert
	#Unless the sampleFormat has a GT of "./.", in which case you would skip it altogether
	if($sampleFormat[0] ne './.'){
		if(scalar(@formatSchema) == scalar(@sampleFormat)){
			#The contents of the sampleFormat is valid and should be transposed to JSON
			#Loop through each value and return the key value pair

			#print special key identifier
			@formatValues = ();
		
			#$study = "\"study\":\"$study\"";
			#$sampleID = "\"sampleID\":\"$sampleID\"";
			push(@formatValues,$md5);
			#$key = "_key : \"$keyName\"";
			#push(@formatValues,$key);
			for ($i=0; $i < @formatSchema; $i++){
				#Skip any data point that is uninformative
				next if($sampleFormat[$i] =~ /\./);
				#Find out if there are 1 or more annotations, and determine if they are strings or numbers
				$val = singleOrMulti($formatSchema[$i],$sampleFormat[$i], $last);
				if($val){
					push(@formatValues,$val);
				}
			}
			$allKeys = join(",", @formatValues);

			# print out the  JSON 
			print sampleJSON "{ $allKeys }\n";
			#die;
		}
	}
}

#Build a function to see if there is a comma
sub singleOrMulti{
	($key,$values) = @_;
	#If the GT variable, then do special processing
	if($key =~ /^GT$/){
		$AN = $values; $AN =~ s/\D//;$AN = length($AN);;
		$AC = $values; $AC =~ s/[\D0]//g; $AC = length($AC);
		$res =  "\"GT\" : \"$values\", \"AC\" : $AC, \"AN\" : $AN";
		return $res;
		next;
	}
	##print "Key=$key\tVal=$values\n";
	if ($values =~ /,/){
		#its an array
		@values = split(",",$values);
		#If the first value is a number, then they are all numbers
		if(looks_like_number($values[0])){
			if($key =~ /^AD$/){
					$res = " \"AD_1\" : $values[0], \"AD_2\" : $values[1]";
					return $res;
				}else{
					#Its just another array
					$newValues = "[" . join(",",@values) ."]";
					$newValues = "\"$key\" : $newValues";
					return $newValues;
			}		
		}else{
			#Its an array of strings
			$newValues = "[\"". join('","', @values) . "\"]";
			$newValues = "\"$key\" : $newValues";
			return $newValues;
		}
	}else{
		#Its a single value
		if(looks_like_number($values)){
			return " \"$key\" : $values";
		}else{
			#its a single string value
			return " \"$key\" : \"$values\"";
		}
	}
}

sub blocks{
	my ($sampleName,$chr,$pos,$end,$format,$sampleFormat) = @_;
	@end=split('=',$end);
	$end_pos=$end[1];
	$block ='sample:"'.$sampleName.'", chr: "'.$chr.'", start:'.$pos.', end:'.$end_pos.',format: "'.$format.'", sampleFormat: "'.$sampleFormat.'"';
print blockJSON "{$block}\n"; 
}

sub infoParse{
	my ($infoItem) = @_;
	my ($key, $value) = split(/=/, $infoItem, 2);
	$value =~ s/\"/\\"/g;
	$key=~s/\./_/g;
	#Skip if the value is '.'
	next if ($value eq '.');
	#print "Key=$key\tValue=$value\n";
	### Because VCF INFO fields can have flags, they don't have an '=' sign.  They need to be treated differently
	if(!$value){
		return "\"$key\" : true";
	}else{
		# It is a traditional key:value pair
		my $result = singleOrMulti($key, $value);
		#print "RES = $result\tkey=$key\tvalue=$value\n";
		return $result;
	}
}

# Look for help flag
if($help){help()}

#Ensure all required parameters are set
validateInput("vcf",$vcf);
validateInput("study_name",$study);

#Make sure study name doesn't have a '-'' sign
$study =~ s/-//g;

######################################################################
###
###  Start Reading in file
###
######################################################################

open(VCF, $vcf) or die "Can't open the VCF\n";
if($strict){
		open(sampleJSON, ">sampleFormat.json") or die "Cont open sampleFormat.json";
	}else{
		open(sampleJSON, ">>sampleFormat.json") or die "Cont open sampleFormat.json";
	}

#open(infoJSON, ">info.json")or die "Cont open info.json";
if($strict){
	open(blockJSON, ">block.json")or die "Cont open block.json";
	}else{
	open(blockJSON, ">>block.json")or die "Cont open block.json";
}

while(<VCF>){
	chomp;
	die if($. == $kill);
	next if($_=~/^##/);
	#Look for the CHROM line to get the sample names
	if($_ =~ /^#CHROM/){
		@SAMPLES = split(/\t/,$_);
	}
	else {
		#remove the chr if it exists, because some VCFs have it, some don't
		$_=~s/^chr//;
		@line = split("\t",$_);

		#### Print out some standard errors to keep me up to dat with progress
		if($. % 1000 == 0){
			$lineNo = sprintf("%.0f", $./8141 * 100);
			print STDERR "Line Number $. of 8141 ($lineNo%)\r";
		}

		#Skip if biallelic setting isn't disabled
		next if(!$biallele && $line[4]=~/,/);


		######################################################################
		### This section will parse out the INFO field and return JSON
		######################################################################
		@INFO = split(";",$line[7]);
		$md5 = join(":",$line[0],$line[1],$line[3],$line[4]);
		$md5 = "\"_key\":\"$md5\"";
		# @infoJSON = ();
		# for($j = 0; $j<@INFO; $j++){
			
		# 	next if (@INFO[$j]=~/^END=/);
		# 	$var = infoParse(@INFO[$j]);
		# 	push(@infoJSON,$var);
		# }

		# $infoJSON = join(",",$md5,@infoJSON);
		# print infoJSON "{$infoJSON}\n" unless ($line[7]=~/^END=/);

		######################################################################
		### This section will parse out the FORMAT fields and return JSON
		######################################################################


		

		for($j = 9; $j<@line; $j++){
			$sampleName = $SAMPLES[$j];
			#Make sure sample name doesn't have a -
			$sampleName =~ s/-//g;
			$chr='chr:"'.$line[0].'"';
			$pos='pos:'.$line[1];
			$ref='ref:"'.$line[3].'"';
			$alt='alt:"'.$line[4].'"';
			$study_name='study:"'.$study.'"';
			$sample_name='sample:"'.$sampleName.'"';
			$md5 = join(",",$sample_name,$chr,$pos,$ref,$alt,$study_name);
			
			$md5 = $md5;

			if ($line[7]=~/END=/){
				blocks($SAMPLES[$j],$line[0],$line[1],$line[7],$line[8],$line[$j]);
			}
			formatParse($line[8],$line[$j],$study,$SAMPLES[$j],$md5);			
		}
	}
}
close VCF;
close sampleJSON;
#close infoJSON;
close blockJSON;
