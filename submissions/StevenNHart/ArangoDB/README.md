Requires the following perl module:
```
Scalar::Util
```

Get input files
```
wget https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/vcfs/1KG.chr22.anno.infocol.vcf.gz
wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/release/20110521/README.sample_cryptic_relations
wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/release/20110521/phase1_integrated_calls.20101123.ALL.panel
```
Transform the VCF sampleFormat and INFO data into JSON for uploading to the database
##### Some important notes:
* If values are strings, then they get quotes
* I skipped any data point that had a null value (`'.'`)
* The INFO field has some HTML links with some funky characters, so be careful when parsing
* I transformed the AD field from an array [in the VCF] to AD_1 and AD_2 so I could query and index it easier
* I gave the VCF a study name to merge with the sample names so I can prevent conflicts in the namespace
```
time bgzip -dc 1KG.chr22.anno.infocol.vcf.gz |perl scripts/VCF2Arango.pl -VCF - -study 1000Genomes 

real	53m28.825s
user	53m21.416s
sys	0m21.003s

```

Transform the cryptic relatedness file into JSON
##### Some important notes:
* I had to skip several lines that didn't have any information

```
perl scripts/parseRelatedness.pl -i README.sample_cryptic_relations
```

The last transformation is for the population descriptions
##### Some important notes:
* This file was supposed to have 4 columns, but someone got a little liberal with the comma usage
 * replacing `ABI_SOLID,` with `ABI_SOLID` fixes the issue

```
perl scripts/parsePopulations.pl -i phase1_integrated_calls.20101123.ALL.panel
```

I now have 4 different json files to import into ArangoDB