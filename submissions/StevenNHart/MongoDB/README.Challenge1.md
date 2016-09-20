Requires the following perl modules:
```
Scalar::Util
```
Also uses mongo 3.2.3
> curl -O https://fastdl.mongodb.org/osx/mongodb-osx-x86_64-3.2.3.tgz

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
* I gave the VCF a study name to merge with the sample names so I can prevent conflicts in the namespace when adding new samples
* I created a varID key by combining "chrom:pos:ref:alt" so I know what variant position I am talking about
```
time zcat 1KG.chr22.anno.infocol.vcf.gz |perl scripts/VCF2Mongo.pl -VCF - -study 1000Genomes 
#Line Number 348000 of 348234 (100%)
#real    37m28.909s
#user    34m53.484s
#sys     0m33.116s
```

Transform the cryptic relatedness file into JSON
##### Some important notes:
* I had to skip several lines that didn't have any information

```
perl scripts/parseRelatedness.pl -i README.sample_cryptic_relations
#real    0m0.018s
#user    0m0.012s
#sys     0m0.000s
```

The last transformation is for the population descriptions
##### Some important notes:
* This file was supposed to have 4 columns, but someone got a little liberal with the comma usage
 * replacing `ABI_SOLID,` with `ABI_SOLID` fixes the issue

```
perl scripts/parsePopulations.pl -i phase1_integrated_calls.20101123.ALL.panel
#real    0m0.026s
#user    0m0.020s
#sys     0m0.000s
```
I now have 4 different json files to import into MongoDB


#Start Mongodb

```
sudo mongod
#change terminal and start the import process

```

#Create single entries to prime the indexes
```
time for x in *json
do
 echo $x
 head -1 $x > ${x}.2
 mongoimport -d test -c ${x/.json/} ${x}.2 
 rm ${x}.2
done

#real    0m1.136s
#user    0m0.016s
#sys     0m0.020s
```

#Add indexes to collections
```
mongo --eval 'db.info.ensureIndex({ Effect_Impact: 1 })'
mongo --eval 'db.info.ensureIndex({ ExAC_Info_AF: 1 })'
mongo --eval 'db.info.ensureIndex({ SAVANT_IMPACT: 1 })'

mongo --eval 'db.sampleFormat.ensureIndex({ chr: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ pos: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ ref: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ alt: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ GT: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ AD_1: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ GQ: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ sampleID: 1 })'

```

#Load full collections
```
time mongoimport -d test -c info info.json
#real    0m26.367s
#user    0m14.608s
#sys     0m0.600s

time mongoimport -d test -c sampleFormat sampleFormat.json
#2016-09-19T18:23:22.558+0000    imported 137584795 documents
#real    159m57.981s
#user    49m15.824s
#sys     2m26.568s

time mongoimport -d test -c cryptic cryptic.json
#2016-09-19T18:34:30.907+0000    imported 40 documents
#real    0m0.014s
#user    0m0.000s
#sys     0m0.008s

time mongoimport -d test -c populations populations.json
#2016-09-19T18:34:57.522+0000    imported 1092 documents
#real    0m0.035s
#user    0m0.012s
#sys     0m0.008s

```

#Build the query
```
mongo --quiet test < scripts/challenge1.js
```
#Result

```
{ "EUR" : 2719, "ASN" : 1641, "AMR" : 53, "AFR" : 3563 }

real    1m33.856s
user    0m2.636s
sys     0m0.252s

```
# Stats:
```
info:  		"storageSize" : 37142528,
cryptic:	"storageSize" : 32768,
sampleFormat:	"storageSize" : 6917197824,
populations:	"storageSize" : 65536


```
