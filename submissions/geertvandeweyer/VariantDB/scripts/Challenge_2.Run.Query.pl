#!/usr/bin/perl

use Getopt::Std;
use JSON;
use LWP::UserAgent;
use strict;
use warnings;
use Data::Dumper;
$|++;

## settings:
my $apply_filter = 'challenge_2'; # the criteria are stored under this name.


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

###############
# READ ID_MAP #
###############
my %id_map = ();
open IN, "$datadir/ID_MAP.txt";
while(<IN>) {
        chomp;
        my ($sname,$sid) = split(/=/,$_);
        $id_map{$sname} = $sid;
}
close IN;



#####################
## SUBMIT THE QUERY #
#####################
my $sid = $id_map{'NA12878'};

$call =  $vdb_url."/SubmitQuery/sample/$sid?fid=$fid&format=vcf&apiKey=$apikey";
$content = $ua->get($call);
$stat = -1;
my $return = {};
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
my $qid = $return->{'query_key'};
print "Submitted as query ".$return->{'query_key'}.", queued at position ".$return->{'queue_position'}."\n";
$return = {};

################################
## WAIT FOR QUERIES TO FINISH ##
################################
print "\n";
print "Waiting for query to finish...\n";
print "================================\n";
my $done = 0;
while ($done == 0) {
	$done = 1;
	# get status.
	my $call =  $vdb_url."/GetStatus/Query/$qid?apiKey=$apikey";
	my $lc = $ua->get($call);
	my $stat = -1;
	my $return = {};
	while ($stat == -1) {
		($stat,$return) = j_decode($lc);
		if ($stat == -1) {
			print "no json obtained.\n";
			sleep 5;
			# try again.
			$lc = $ua->get($call);
			next;
		}
		
	}
	if (!defined($return->{'status'}) || $return->{'status'} ne 'finished') {
		$done = 0;
		sleep 10;
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

	my $vcf = $return->{'VCF'};
	open OUT, ">$datadir/Passed.Variants.vcf";
	print OUT $vcf;
	close OUT;
	my $variants = $return->{'Variants'};
	print "RESULT:\n";
	print "  Number of passing variants: ".scalar(@$variants)."\n";
}

print "\nAll done.\n";



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
	
	
