#! /usr/bin/env perl

use Getopt::Long;

GetOptions ("input|i=s" => \$input,    # string
            "help|h"  => \$help);   # flag

#Create help and usage statement
sub help{
	print "Usage: perl parsePopulations.pl -i <phase1_integrated_calls.20101123.ALL.panel> 
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

open(OUT, ">populations.json") or die "Can't open the output file: populations.json\n\n";
open(FILE,"$input") or die "Can't open the input file: $input\n\n";
@HEADERS = ("SAMPLE","Pop1", "Pop2", "Instrument1", "Instrument2");
while(<FILE>){
	chomp;
	$_ =~ s/ABI_SOLID,/ABI_SOLID/;
	@line = split("\t", $_ );
	@jsonLine = ();
	for ($i=0; $i<@line; $i++){
		#For strings, the values need to be in quotes
		$jsonLine=' '. @HEADERS[$i] . ':'. '"'.$line[$i]. '"';
		push (@jsonLine,$jsonLine);
		}
		$jsonLine =join(',', @jsonLine);
		print OUT "{".$jsonLine."}\n"; 
}

close OUT;
close FILE;