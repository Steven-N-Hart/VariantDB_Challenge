#!/usr/bin/perl

use Getopt::Std;
use JSON;
use LWP::UserAgent;
use strict;
use warnings;
$|++;
# download links.
my $cryptic_url = "ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/release/20110521/README.sample_cryptic_relations";
my $population_url = "ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/release/20110521/phase1_integrated_calls.20101123.ALL.panel";

###############
## arguments ##
###############
# d : data_dir of import
# u : url of VariantDB
# a : apikey
our %opts = ();
getopts("d:u:a:h", \%opts);
print "\nStarting...\n\n";
if (defined($opts{'h'})) {
	&PrintHelp;	
}
if (!-d $opts{'d'}) {
	print "ERROR: No data_dir provided\n";
	&PrintHelp;
}
my $datadir = $opts{'d'};
if (!defined($opts{'u'}) || $opts{'u'} !~ m/^http/) {
	print "WARNING: No/invalid URL provided for VariantDB. The main server will be used (http://143.169.238.105/variantdb/)\n";
	$opts{'u'} = 'http://143.169.238.105/variantdb/';
}
my $vdb_url = $opts{'u'}."/api";

if (!defined($opts{'a'}) || $opts{'a'} eq '') {
	print "ERROR: No apiKey provided for VariantDB. To get one, register on the website and activate api-access under user details (menu located under the username in the top right corner)\n";
	&PrintHelp;
}
my $apikey = $opts{'a'};

########################################	
# check if connection & api key are ok.#
########################################
my $ua = LWP::UserAgent->new;
my $url = $vdb_url."/CheckApiKey?apiKey=$apikey";
my $content = $ua->get($url);
my $return = $content->decoded_content;
$return =~ s/"//g;
if ($return ne '1') {
	print "ERROR: Connection failed or apikey is not valid.\n";
	&PrintHelp;
}
print "Connection to VariantDB established!\n";



###########################
## get the needed files. ##
###########################
print "Downloading $cryptic_url\n";
system("wget -q -O '$datadir/cryptic.relations.txt' '$cryptic_url'");
if (!-e "$datadir/cryptic.relations.txt") {
	print "Could not download '$cryptic_url' \n";
	exit;
}
print "Downloading $population_url\n";
system("wget -q -O '$datadir/populations.txt' '$population_url'");
if (!-e "$datadir/populations.txt") {
	print "Could not download '$population_url' \n";
	exit;
}

## ########################
## read id_map from file. #
###########################
my %id_map = ();
open IN, "$datadir/ID_MAP.txt";
while(<IN>) {
	chomp;
	my ($sname,$sid) = split(/=/,$_);
	$id_map{$sname} = $sid;
}
close IN;	

#########################
## GET PROJECT DETAILS ##
#########################
open IN, "$datadir/ProjectID.txt" or die("Could not read $datadir/ProjectID.txt\n");
my $pid = <IN>;
chomp($pid);
close IN;
my $call =  $vdb_url."/Projects/$pid?apiKey=$apikey";
$content = $ua->get($call);
$return = decode_json($content->decoded_content);
if (!defined($return->{'project_name'}) ) {
	print "ERROR: Unable to get Project details.\n";
	if (defined($return->{'error'})) {
		print $return->{'error'}."\n";
	}
	exit;
}
my $project_name = $return->{'project_name'};

################################
# load the cryptic relations. ##
################################
my %cryptic = ();
open IN, "$datadir/cryptic.relations.txt" or die("Could not open $datadir/cryptic.relations.txt\n");
my $line = <IN>;
while ($line !~ m/^Population\t/) {
	$line = <IN>;
}
while (<IN>) {
	chomp;
	next if ($_ eq "");
	my ($population,$s1,$s2,$rel,$ibd0,$ibd1,$ibd2) = split(/\t/,$_);
	if ($population ne 'ASW' || $rel ne 'Sibling') {
		$cryptic{$population}{$s1} = $rel;
		$cryptic{$population}{$s2} = $rel;
	}
}
close IN;

######################################################
## organise samples into population based projects. ##
######################################################
my %projects = ();
open IN, "$datadir/populations.txt";
print "Organising samples into new projects\n";
my %stats = ();
while (<IN>) {
	chomp;
	next if ($_ eq "") ;
	my @c = split(/\t/,$_);
	# get sample id
	my $sample = $c[0];
	if (!defined($id_map{$sample})) {
		$stats{'not_found'}{$sample} = 1;
		#print "  WARNING : sample $sample not found in id_map. skipped\n";
		next;
	}
	my $sid = $id_map{$sample};
	# get target project id
	my $population = $c[2];
	my $sub_pop = $c[1];
	my $target_project = "$project_name"."_$population";
	# exclude the cryptic related samples;
	if (defined($cryptic{$sub_pop}{$sample})) {
		$target_project .= "_cryptic";
	}
	print "  - $sample => $target_project\n";
	$stats{'by_project'}{$target_project}{$sample} = 1;
	$stats{'done'}{$sample} = 1;
	if (!defined($projects{$target_project})) {
		# new population, create the target project.
		my $call =  $vdb_url."/CreateProject/$target_project?apiKey=$apikey";
		$content = $ua->get($call);
		$return = decode_json($content->decoded_content);
		if (!defined($return->{'project_id'}) ) {
			print "ERROR: Unable to create Project.\n";
			if (defined($return->{'error'})) {
				print $return->{'error'}."\n";
			}
			exit;
		}
		my $new_pid = $return->{'project_id'};
		$projects{$target_project} = $new_pid;
	}
	my $target_pid = $projects{$target_project};
	# move the sample
	my $call = $vdb_url."/MoveSample/$sid?f=$pid&t=$target_pid&apiKey=$apikey";
	$content = $ua->get($call);
	$return = decode_json($content->decoded_content);
	if (!defined($return->{'result'}) || $return->{'result'} ne 'ok' ) {
		print "ERROR: Unable to move sample.\n";
		if (defined($return->{'error'})) {
			print $return->{'error'}."\n";
		}
		exit;
	}
	
}
print " - Nr of samples in new projects:\n";
foreach my $p (keys(%{$stats{'by_project'}})) {
	print "   - $p : ".keys(%{$stats{'by_project'}{$p}})."\n";
}
print " - Nr of samples from population file that were not in imported VCF: ".keys(%{$stats{'not_found'}})."\n";
if (keys(%{$stats{'done'}}) < keys(%id_map)) {
	my $nr = 0;
	print " - The following samples from imported VCF were not in population file:\n";
	foreach my $s (keys(%id_map)) {
		if (!defined($stats{'done'}{$s})) {
			print "   - $s\n";
			$nr++;
		}
	}
	
	print " => These $nr samples were left in '$project_name'\n";
}


print "\nWriting out project IDs.\n";
open OUT, ">$datadir/project.map.txt";
foreach(keys(%projects)) {
	print OUT "$_\t$projects{$_}\n";
}
close OUT;

print "\nAll done.\n";









sub PrintHelp {
	print "\nHow to use: \n";
	print "perl SetRelations.pl -d data_dir -u 'http://143.169.238.105/variantdb' -a 'my_api_key'\n";
	print "\n";
	print "Data_Dir is the location where Import.URL.Data.pl was successfully executed. It contains the following mandatory files:\n";
	print " - ID_MAP.txt : Holds the sample_ids in VariantDB of the imported samples\n";
	print " - ProjectID.txt : Holds the id in VariantDB of the created project\n";
	print "\n";
	print "The following datafiles are being used to set relations:\n";
	print "  - $cryptic_url\n";
	print "  - $population_url\n";
	print "\n";
	print exit;
}
	
	
