#!/usr/bin/perl

use Getopt::Std;
use JSON;
use LWP::UserAgent;
use strict;
use warnings;
$|++;


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

##########################
## SET FAMILY RELATIONS ##
##########################
# set gender of 12878
my $index = $id_map{'NA12878'};
$call = $vdb_url."/SetSampleDetails/$index?set=gender&value=female&apiKey=$apikey";
$content = $ua->get($call);
$return = decode_json($content->decoded_content);
if (!defined($return->{'status'}) ) {
	print "ERROR: Unable to set gender.\n";
	if (defined($return->{'error'})) {
		print $return->{'error'}."\n";
	}
	exit;
}
# 12891 is father of 12878
my $father = $id_map{'NA12891'};
$call = $vdb_url."/SetSampleDetails/$father?set=gender&value=male&apiKey=$apikey";
$content = $ua->get($call);
$return = decode_json($content->decoded_content);
if (!defined($return->{'status'}) ) {
	print "ERROR: Unable to set gender.\n";
	if (defined($return->{'error'})) {
		print $return->{'error'}."\n";
	}
	exit;
}
$call = $vdb_url."/SetSampleDetails/$index?set=parent&value=$father&apiKey=$apikey";
$content = $ua->get($call);
$return = decode_json($content->decoded_content);
if (!defined($return->{'status'}) ) {
	print "ERROR: Unable to set parental relation.\n";
	if (defined($return->{'error'})) {
		print $return->{'error'}."\n";
	}
	exit;
}

# 12892 is mother of 12878
my $mother = $id_map{'NA12892'};
$call = $vdb_url."/SetSampleDetails/$mother?set=gender&value=female&apiKey=$apikey";
$content = $ua->get($call);
$return = decode_json($content->decoded_content);
if (!defined($return->{'status'}) ) {
	print "ERROR: Unable to set gender.\n";
	if (defined($return->{'error'})) {
		print $return->{'error'}."\n";
	}
	exit;
}
$call = $vdb_url."/SetSampleDetails/$index?set=parent&value=$mother&apiKey=$apikey";
$content = $ua->get($call);
$return = decode_json($content->decoded_content);
if (!defined($return->{'status'}) ) {
	print "ERROR: Unable to set parental relation.\n";
	if (defined($return->{'error'})) {
		print $return->{'error'}."\n";
	}
	exit;
}


print "\nAll done.\n";









sub PrintHelp {
	print "\nHow to use: \n";
	print "perl Challenge_1.SetRelations.pl -d data_dir -u 'http://143.169.238.105/variantdb' -a 'my_api_key'\n";
	print "\n";
	print "Data_Dir is the location where Import.URL.Data.pl was successfully executed. It contains the following mandatory files:\n";
	print " - ID_MAP.txt : Holds the sample_ids in VariantDB of the imported samples\n";
	print " - ProjectID.txt : Holds the id in VariantDB of the created project\n";
	print "\n";
	print "The provided samples are a family trio. Set the appropriate relations\n";
	print "\n";
	print exit;
}
	
	
