


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
bgzip -dc 1KG.chr22.anno.infocol.vcf.gz |perl scripts/VCF2Mongo.pl -VCF - -study 1000Genomes 

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
I now have 4 different json files to import into MongoDB.


Next, create a docker-machine instance that is parameterized appropriately for skydns (to manage ports)
```
# Based on the tutorial from: 
# https://vinayaksb.wordpress.com/2015/11/17/how-to-setup-a-mongodb-sharded-cluster-using-docker-with-skydns/
# but reconfigured to work with docker-machine

DNS=172.17.0.1
docker-machine create -d virtualbox -engine-opt dns=$DNS --engine-opt bip=$DNS/16 mongoHadoop
eval $(docker-machine env mongoHadoop)
```

## Create the cluster based on your own configuration
```
if [ ! -d data/db ]
then
	mkdir -p data/db
fi 
sh create_cluster.sh 
```
> Note, for testing, be sure to set the data (-D) directory path. Run `sh create_cluster.sh  -h` for details.

## log into the cluster you've created and enable sharding
```
# Start the mongo container
docker run -it stevenhart/mongo-spark mongo --host router.mongo-spark.dev.docker 
use challenge1
sh.enableSharding("challenge1")
db.info.ensureIndex({ Effect_Impact: 1 });
db.info.ensureIndex({ ExAC_Info_AF: 1 });
db.info.ensureIndex({ SAVANT_IMPACT: 1 });

db.sampleFormat.ensureIndex({ chr: 1 });
db.sampleFormat.ensureIndex({ pos: 1 });
db.sampleFormat.ensureIndex({ ref: 1 });
db.sampleFormat.ensureIndex({ alt: 1 });
db.sampleFormat.ensureIndex({ GT: 1 });
db.sampleFormat.ensureIndex({ AD_1: 1 });
db.sampleFormat.ensureIndex({ GQ: 1 });
db.sampleFormat.ensureIndex({ sampleID: 1 });

# Select the shard key
sh.shardCollection("challenge1.sampleFormat", { "chr": 1, "pos" : 1, "ref" : 1, "alt": 1} )
exit
```

#Load full collections
```
docker run -v $PWD:/home -w /home -it stevenhart/mongo-spark mongoimport -d challenge1 -c info info.json --host router.mongo-spark.dev.docker
docker run -v $PWD:/home -w /home -it stevenhart/mongo-spark mongoimport -d challenge1 -c cryptic cryptic.json --host router.mongo-spark.dev.docker
docker run -v $PWD:/home -w /home -it stevenhart/mongo-spark mongoimport -d challenge1 -c populations populations.json --host router.mongo-spark.dev.docker
docker run -v $PWD:/home -w /home -it stevenhart/mongo-spark mongoimport -d challenge1 -c sampleFormat sampleFormat.json --host router.mongo-spark.dev.docker
```

#Build the query
```
docker run -v $PWD:/home -w /home -it stevenhart/mongo-spark mongo  --host router.mongo-spark.dev.docker challenge1 scripts/challenge1.js
```

