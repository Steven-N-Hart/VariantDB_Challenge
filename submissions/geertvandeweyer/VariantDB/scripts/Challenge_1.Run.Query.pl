#!/usr/bin/perl

use Getopt::Std;
use JSON;
use LWP::UserAgent;
use strict;
use warnings;
use Data::Dumper;
$|++;

## settings:
my $apply_filter = 'Challenge_1'; # the criteria are stored under this name.


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



#################################
## read projects ids from file. #
#################################
my %project_map = ();
open IN, "$datadir/project.map.txt";
while(<IN>) {
	chomp;
	my ($pname,$pid) = split(/\t/,$_);
	$project_map{$pname} = $pid;
}
close IN;	
##########################
## GET NEEDED FILTER ID.##
## #######################
my $call =  $vdb_url."/SavedFilters?apiKey=$apikey";
$content = $ua->get($call);
my $stat = -1;
while ($stat == -1) {
	($stat,$return) = j_decode($content);
	if ($stat == -1) {
		print "no json obtained.\n";
		sleep 5;
		$content = $ua->get($call);
		next;
	}
	
}
if (ref($return) eq 'HASH' && defined($return->{'error'})) {

	print $return->{'error'}."\n";
	exit;
}
my $fid = -1;
foreach my $filter (@$return) {
	if ($filter->{'FilterName'} eq $apply_filter) {
		$fid = $filter->{'fid'};
		last;
	}
}
if ($fid == -1) {
	print "requested filter set ($apply_filter) not found.\n";
	exit;
}


##########################
## GET FILTER DETAILS . ##
## #######################
$call =  $vdb_url."/SavedFilters/$fid?apiKey=$apikey";
$content = $ua->get($call);
$stat = -1;
while ($stat == -1) {
	($stat,$return) = j_decode($content);
	if ($stat == -1) {
		print "no json obtained.\n";
		sleep 5;
		$content = $ua->get($call);
		next;

	}
}
if (!defined($return->{'FilterName'})) {
	print "Unable to fetch filter details.\n";
	if (defined($return->{'error'})) {
		print $return->{'error'}."\n";
	}
	exit;
}
open OUT, ">$datadir/filter.settings.json";
print OUT $content->decoded_content;
close OUT;

#######################
## SUBMIT THE QUERIES #
#######################
my %qids = ();
foreach my $project (keys(%project_map)) {
	# samples listed in cryptic relations are in 'xx_cryptic' projects.
	next if ($project =~ m/_cryptic/);
	# construct the call.
	my $pid = $project_map{$project};
	my $call =  $vdb_url."/SubmitQuery/project/$pid?fid=$fid&apiKey=$apikey";
	$content = $ua->get($call);
	my $stat = -1;
	while ($stat == -1) {
		($stat,$return) = j_decode($content);
		if ($stat == -1) {
			print "no json obtained. Sleep & try again.\n";
			# try again.
			sleep 5;
			$content = $ua->get($call);
			next;
		}
	}
	# store the query_id by population:
	$qids{$project} = $return->{'query_key'};
	print "Population ".substr($project,-3). " submitted as query ".$return->{'query_key'}.", queued at position ".$return->{'queue_position'}."\n";
}

################################
## WAIT FOR QUERIES TO FINISH ##
################################
print "\n";
print "Waiting for queries to finish...\n";
print "================================\n";
my $done = 0;
my %pop_counter = ();
my %done_qids  =();
while ($done == 0) {
	$done = 1;
	foreach my $project (keys(%qids)) {
		my $qid = $qids{$project};
		if (defined($done_qids{$qid})) {
			next;
		}
		# get status.
		my $call =  $vdb_url."/GetStatus/Query/$qid?apiKey=$apikey";
		$content = $ua->get($call);
		my $stat = -1;
		while ($stat == -1) {
			($stat,$return) = j_decode($content);
			if ($stat == -1) {
				print "no json obtained.\n";
				sleep 5;
				# try again.
				$content = $ua->get($call);
				next;
			}
			
		}
		if ($return->{'status'} ne 'finished') {
			$done = 0;
			next;
		}
		## query finished. get results.

		$call =  $vdb_url."/GetQueryResults/$qid?apiKey=$apikey";
		$content = $ua->get($call);
		$stat = -1;
		while ($stat == -1) {
			($stat,$return) = j_decode($content);
			if ($stat == -1) {
				print "no json obtained.\n";
				sleep 5;
				# try again.
				$content = $ua->get($call);
				next;
			}
		}
		my $counter = 0;
		my $variants = $return->{'Variants'};
		open OUT, ">>$datadir/Passed.Variants.txt\n";

		foreach my $variant (@$variants) {
			my $samples = $variant->{'sample_specific_annotations'};
			my $nr_samples = keys(%$samples);
			print OUT "$project\t$variant->{'general_annotations'}->{'chr'}:$variant->{'general_annotations'}->{'position'}\t$variant->{'general_annotations'}->{'ref_allele'}/$variant->{'general_annotations'}->{'alt_allele'}";
			foreach(keys(%$samples)) {
				print OUT "\t".$samples->{$_}->{'sample_details'}->{'sample_name'};
			}
			print OUT "\n";	
			$counter += $nr_samples;	
	
		}
		close OUT;
		$pop_counter{substr($project,-3)} = $counter;
		print " - ".substr($project,-3) . " is finished\n";
		$done_qids{$qid} = 1;
	}
	sleep 5;
}
print "\nAll done.\n";

print "Results: \n";
foreach(keys(%pop_counter)) {
	print " - $_ : $pop_counter{$_}\n";
}


sub j_decode {
	my ($c) = @_;
	my $d = $c->decoded_content;
	my $r;
	eval  {
		$r = decode_json($d);
		1;
	}
	or do {
		# temporary failure?
		print "Could not valid catch response from server. response was: ";
		
		print Dumper($d);
		my @result = (-1,'');
		return @result;
	};
	my @result = (1,$r);
	return @result;

}






sub PrintHelp {
	print "\nHow to use: \n";
	print "perl Run.Query.pl -d data_dir -u 'http://143.169.238.105/variantdb' -a 'my_api_key'\n";
	print "\n";
	print "Data_Dir is the location where Import.URL.Data.pl and Set.Relations.pl was successfully executed. It contains the following mandatory files:\n";
	print " - ID_MAP.txt : Holds the sample_ids in VariantDB of the imported samples\n";
	print " - project.map.txt\n";
	print "\n";
	print "The following settings are applied:\n";
	print "  - Saved FilterSet : $apply_filter\n";
	print "  - Queries are executed per population, excluding cryptic samples.\n";
	print "  - No additional annotations are requested\n";
	print "\n";
	print exit;
}
	
	
