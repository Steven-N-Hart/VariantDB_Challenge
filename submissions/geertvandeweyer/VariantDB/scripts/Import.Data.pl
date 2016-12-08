#!/usr/bin/perl

use Getopt::Std;
use JSON;
use LWP::UserAgent;
use Data::Dumper;
use File::Basename;
use strict;
use warnings;

# arguments
# s : samplesheet
# u : url of VariantDB
# a : apikey
# p : project name
# c : custom field string.
# l : lockdown mode: VariantDB is brought down to speed up import.
our %opts = ();
getopts("s:u:a:p:c:hl", \%opts);
print "\nStarting...\n\n";
if (defined($opts{'h'})) {
	&PrintHelp;	
}
if (!-f $opts{'s'}) {
	print "ERROR: No Samplesheet provided\n";
	&PrintHelp;
}
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

# get basename of samplesheet
my $datadir = dirname($opts{'s'});

# check if connection & api key are ok.
my $ua = LWP::UserAgent->new;
my $url = $vdb_url."/CheckApiKey?apiKey=$apikey";
my $content = $ua->get($url);
my $return = $content->decoded_content;
$return =~ s/"//g;
if ($return ne '1') {
	print "ERROR: Connection failed or apikey is not valid.\n";
	&PrintHelp;
}
print "Connection established!\n";

# construct the api call to create the import folder on the server.
my $call = $vdb_url."/PrepareImportData";#?apiKey=$apikey";
open IN, $opts{'s'} or die("Could not open samplesheet for reading\n");
my $i = 0;
my %form = ("apiKey" => "$apikey");
while (<IN>) {
	chomp;
	my ($n,$g,$v,$b,$s,$f) = split(/\t/,$_);
	$i++;
	$form{"n$i"} = $n;
	$form{"g$i"} = $g;
	$form{"v$i"} = $v;
	$form{"b$i"} = $b;
	$form{"s$i"} = $s;
	$form{"f$i"} = $f;
	#$call .= "&n$i=$n&g$i=$g&v$i=$v&b$i=$b&s$i=$s&f$i=$f";
}
close IN;
# project defined? 
if (defined($opts{'p'}) && $opts{'p'} ne '') {
	# add project name if provided.
	#$call .= "&p=".$opts{'p'};
	$form{"p"} = $opts{'p'};
}
# custom fields? 
if (defined($opts{'c'})) {
	my %accepted = ('varchar' => 1,'integer'=> 1,'decimal' => 1, 'float' => 1, 'list' => '1');
	my $idx = 0;
	my @items = split(/,/,$opts{'c'});
	foreach my $item (@items) {
		$idx++;
		my ($k,$t) = split(/=/,$item);
		$t = lc($t);
		if (!defined($accepted{$t})) {
			print "WARNING: field type '$t' is not accepted. Setting to generic 'varchar' type\n";
		}
		if ($t eq 'float') {
			print "NOTE : floating point will be considered as a decimal.\n";
			$t = 'decimal';
		}
		#$call .= "&cf_name$idx=$k&cf_type$idx=$t";
		$form{"cf_name$idx"} = $k;
		$form{"cf_type$idx"} = $t;
	}
}
# just add the lockdown, it's ignored for non admin users.
if (defined($opts{'l'})) {
	$form{'l'} = 1;
}

my $nr_samples = $i;
$content = $ua->post($call,\%form);
my $stat = -1;
while ($stat == -1) {
	($stat,$return) = j_decode($content);
	if ($stat == -1) {
		print "no json obtained.\n";
		sleep 5;
		$content = $ua->post($call,\%form);
		next;
	}
}
if (!defined($return->{'status'}) || $return->{'status'} ne 'ok') {
	print "ERROR: Preparation of the import job failed.";
	if (defined($return->{'ERROR'})) {
		print $return->{'ERROR'};
	}
	exit;
}
my $path = $return->{'path'};
# submit the actual import.
$call =  $vdb_url."/ImportData/$path/$nr_samples?apiKey=$apikey";
$stat = -1;
$content = $ua->get($call);
while ($stat == -1) {
	($stat,$return) = j_decode($content);
	if ($stat == -1) {
		print "no json obtained.\n";
		sleep 5; 
		$content = $ua->get($call);
		next;
	}
}
if (!defined($return->{'result'}) || $return->{'result'} ne 'Started') {
	print "ERROR: Unable to start the import Job.\n";
	if (defined($return->{'error'})) {
		print $return->{'error'}."\n";
	}
	exit;
}
my $importKey = $return->{'job_key'};
print " => Import started with job key : $importKey\n";
# now wait for the import to finish.
my $finished = '';
while ($finished ne 'Finished') {
	# poll every 30s
	sleep 15;
	my $status_call = $vdb_url."/GetStatus/Import/$importKey?apiKey=$apikey";
	my $stat = -1;
	$content = $ua->get($status_call);
	($stat,$return) = j_decode($content);
	if ($stat == -1) {
		print "no json obtained.\n";
		sleep 5; 
		$content = $ua->get($status_call);
		next;
	}
	if (defined($return->{'ERROR'}) ) {
		print $return->{'ERROR'}."\n";
		exit;
	}
	$finished = $return->{'status'};
}

## import finished, store some details.
open OUT, ">$datadir/import.log";
print OUT $return->{'runtime_output'};
close OUT;
open OUT, ">$datadir/ProjectID.txt";
print OUT $return->{'ProjectID'};
close OUT;
my %id_map = ();
open OUT, ">$datadir/ID_MAP.txt";
foreach my $sname (keys(%{$return->{'id_map'}})) {
	$id_map{$sname} = $return->{'id_map'}->{$sname};
	print OUT "$sname=".$id_map{$sname}."\n";
}
close OUT;



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
	print "perl Import.URL.Data.pl -s samplesheet.txt -u 'http://143.169.238.105/variantdb' -a 'my_api_key' -p project_name -c 'Dels=decimal,MQ0=integer'\n";
	print "\n";
	print "Samplesheet is structured with the following columns, without headers: \n";
	print " - sample_name : an arbitrary name\n";
	print " - gender : undef, male, female\n";
	print " - URL or path on VariantDB server of the VCF file\n";
	print " - URL or path on VariantDB server of the BAM file\n";
	print " - Store the VCF/BAM after import? 0 or 1\n";
	print " - VCF Format : \n";
	print "     - UG : Unified Genotyper\n";
	print "     - HC : HaplotypeCaller\n";
	print "     - MT : MuTect\n";
	print "     - VSC : VarScan Cohort\n";
	print "     - VS : Varscan paired samples\n";
	print "     - 23 : 23andMe array data, converted to genotypes\n";
	print "     - IT : ion-torrent (experimental)\n";
	print "\n";
	print "For UG/HC, cohort VCF files can be loaded using by specifying '%cohort%' as samplename\n";
	print "\n";
	print "The -c argument takes a list of custom info/format fields that must be stored, apart from the default set of annotations. Format is a comma-seperated list of field_name=field_type tuples, where field_type is one of (integer,decimal,varchar,list). Varchar is a variable string up to 255 characters. List is a more performant option to store strings, when the number of different values is limited.\n";
	print "\n";
	print exit;
}
	
