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
# Build a sharded cluster 

|IP-address|hostname|
|10.0.0.20|hn0-varian|
|10.0.0.18|wn1-varian|
|10.0.0.14|wn2-varian|
|10.0.0.10|wn3-varian|

# Build a sharded cluster 

|IP-address|hostname|
|10.0.0.20|hn0-varian|
|10.0.0.18|wn1-varian|
|10.0.0.14|wn2-varian|
|10.0.0.10|wn3-varian|


##################################################################################
LOGPATH=/home/m087494/logpath
mkdir -p $LOGPATH/cfg0 $LOGPATH/cfg1 $LOGPATH/cfg2 $LOGPATH/a0 $LOGPATH/a1 $LOGPATH/a2
mongod --configsvr --port 26050 --logpath $LOGPATH/log.cfg0 --dbpath $LOGPATH/cfg0 --fork
mongod --configsvr --port 26051 --logpath $LOGPATH/log.cfg1 --dbpath $LOGPATH/cfg1 --fork
mongod --configsvr --port 26052 --logpath $LOGPATH/log.cfg2 --dbpath $LOGPATH/cfg2 --fork

mongod --shardsvr --replSet a --dbpath $LOGPATH/a0 --logpath $LOGPATH/log.a0 --port 27000 --fork
mongod --shardsvr --replSet a --dbpath $LOGPATH/a1 --logpath $LOGPATH/log.a1 --port 27001 --fork
mongod --shardsvr --replSet a --dbpath $LOGPATH/a2 --logpath $LOGPATH/log.a2 --port 27002 --fork

mongos --configdb hn0-varian:26050,hn0-varian:26051,hn0-varian:26052 --fork --logpath $LOGPATH/log.mongos0
mongos --configdb hn0-varian:26050,hn0-varian:26051,hn0-varian:26052 --fork --logpath $LOGPATH/log.mongos1 --port 26061

mongo --port 27000
rs.initiate()
rs.add("hn0-varian:27001")
rs.add("hn0-varian:27002")
exit

##################################################################################
#On Machine 2 [wn1]
LOGPATH=/home/m087494/logpath
mkdir -p $LOGPATH/b0 $LOGPATH/b1 $LOGPATH/b2
mongod --shardsvr --replSet b --dbpath $LOGPATH/b0 --logpath $LOGPATH/log.b0 --port 27000 --fork
mongod --shardsvr --replSet b --dbpath $LOGPATH/b1 --logpath $LOGPATH/log.b1 --port 27001 --fork
mongod --shardsvr --replSet b --dbpath $LOGPATH/b2 --logpath $LOGPATH/log.b2 --port 27002 --fork

mongo --port 27000
rs.initiate()
rs.add("wn1-varian:27001")
rs.add("wn1-varian:27002")
exit

##################################################################################
#On Machine 3 [wn2]
LOGPATH=/home/m087494/logpath
mkdir -p $LOGPATH/c0 $LOGPATH/c1 $LOGPATH/c2
mongod --shardsvr --replSet c --dbpath $LOGPATH/c0 --logpath $LOGPATH/log.c0 --port 27000 --fork
mongod --shardsvr --replSet c --dbpath $LOGPATH/c1 --logpath $LOGPATH/log.c1 --port 27001 --fork
mongod --shardsvr --replSet c --dbpath $LOGPATH/c2 --logpath $LOGPATH/log.c2 --port 27002 --fork

mongo --port 27000
rs.initiate()
rs.add("wn2-varian:27001")
rs.add("wn2-varian:27002")
exit

##################################################################################
#Add shards on Machine 1
mongo
sh.status()
sh.addShard("a/hn0-varian:27000")
sh.addShard("b/wn1-varian:27000")
sh.addShard("c/wn2-varian:27000")
sh.status()
sh.enableSharding("test")
sh.shardCollection("test.sampleFormat", { _id : "hashed" } )
exit
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



#Create single entries to prime the indexes
```
time for x in *json
do
 echo $x
 head -1 $x > ${x}.2
 mongoimport --drop -d test -c ${x/.json/} ${x}.2 
 rm ${x}.2
done

#real    0m1.511s
#user    0m0.028s
#sys     0m0.008s
```

#Add indexes to collections
```
mongo --eval 'db.info.ensureIndex({ Effect_Impact: 1 })'
mongo --eval 'db.info.ensureIndex({ ExAC_Info_AF: 1 })'
mongo --eval 'db.info.ensureIndex({ SAVANT_IMPACT: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ chr: 1})'
mongo --eval 'db.sampleFormat.ensureIndex({ pos: 1})'
mongo --eval 'db.sampleFormat.ensureIndex({ alt: 1})'
mongo --eval 'db.sampleFormat.ensureIndex({ ref: 1})'
mongo --eval 'db.sampleFormat.ensureIndex({ GT: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ AD_1: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ GQ: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ sampleID: 1 })'
```

#Load full collections
```
time mongoimport  -d test -c info --numInsertionWorkers 10 info.json
#real    0m18.833s
#user    0m15.412s
#sys     0m0.548s

time mongoimport -d test -c cryptic cryptic.json
#real    0m0.147s
#user    0m0.008s
#sys     0m0.008s

time mongoimport -d test -c populations populations.json 
#2016-09-19T18:34:57.522+0000    imported 1092 documents
#real    0m0.019s
#user    0m0.012s
#sys     0m0.008s

time mongoimport -d test -c sampleFormat --numInsertionWorkers 50 sampleFormat.json 
#real    107m34.199s
#user    63m24.472s
#sys     1m54.664s

```

#Build the query
```
time mongo --quiet test < scripts/challenge1.js

{ "EUR" : 2701, "ASN" : 1642, "AMR" : 53, "AFR" : 3563 }

#real    3m30.407s
#user    0m2.764s
#sys     0m0.308s


```
# Stats:
```
info:  		 "storageSize" : 42307584,
cryptic:	 "storageSize" : 32768,
sampleFormat:"storageSize" : 7021670400,
populations:	"storageSize" : 65536


```
# Based on http://www.mongodbspain.com/en/2015/01/26/how-to-set-up-a-mongodb-sharded-cluster/
