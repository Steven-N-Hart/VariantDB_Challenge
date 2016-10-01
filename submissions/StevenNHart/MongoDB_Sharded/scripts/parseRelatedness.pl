#! /usr/bin/env perl

use Getopt::Long;

GetOptions ("input|i=s" => \$input,    # string
            "help|h"  => \$help);   # flag

#Create help and usage statement
sub help{
	print "Usage: perl parseRelatedness.pl -i <README.sample_cryptic_relations> 
		Options:

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

# Look for help flag
if($help){help()}

#Ensure all required parameters are set
validateInput("input",$input);

open(OUT, ">cryptic.json") or die "Can't open the output file: cryptic.json\n\n";
open(FILE,"$input") or die "Can't open the input file: $input\n\n";
while(<FILE>){
	chomp;
	#Skip the blank  & extra lines from file
	next if ($. < 4);
	#Get the column Headers
	if($. == 4){
		$_ =~ s/ /_/g;
		@HEADERS = split("\t",$_);
	} else{
		#These are the lines that actually contain data
		@line = split("\t", $_ );
		@jsonLine = ();
		for ($i=0; $i<@line; $i++){
			#For strings, the values need to be in quotes
			if($i<4){$newLine = ' "'.@line[$i].'"'}else{$newLine=@line[$i]}
			$jsonLine=' "'. @HEADERS[$i] . '":'. $newLine;
			push (@jsonLine,$jsonLine);
		}
		$jsonLine =join(',', @jsonLine);
		print OUT "{".$jsonLine."}\n"; 
	}
}

close OUT;
close FILE;