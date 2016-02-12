Requires the following perl modules:
```
Scalar::Util
```

Get input files
```
wget -O NA12878.chr22.g.vcf.gz http://bioinformaticstools.mayo.edu/research/wp-content/plugins/download.php?url=https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/gvcfs/NA12878.chr22.g.vcf.gz
wget -O NA12891.chr22.g.vcf.gz http://bioinformaticstools.mayo.edu/research/wp-content/plugins/download.php?url=https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/gvcfs/NA12891.chr22.g.vcf.gz
wget -O NA12892.chr22.g.vcf.gz http://bioinformaticstools.mayo.edu/research/wp-content/plugins/download.php?url=https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/gvcfs/NA12892.chr22.g.vcf.gz

```

#Filter the gVCFs to contain genotype quality values > 20 and then create JSON files
```
for x in *gz
do
	echo ${x/g.vcf.gz/gq20.g.vcf}
	bgzip -dc $x|perl scripts/FormatFilter.pl - > ${x/g.vcf.gz/gq20.g.vcf}
	perl scripts/gVCF_split.pl -i ${x/g.vcf.gz/gq20.g.vcf}|perl scripts/gVCF2Arango.pl -v - -s 1000Genomes
	rm ${x/g.vcf.gz/gq20.g.vcf}
done

```
# Set up arangodb cluster by turnging off some default features

# TODO: Install sharded cluster
```
CONF=/Applications/ArangoDB-CLI.app/Contents/MacOS//opt/arangodb/etc/arangodb/arangod.conf

perl -p -i -e 's/disable-dispatcher-kickstarter = yes/disable-dispatcher-kickstarter = false/;s/disable-dispatcher-frontend = yes/disable-dispatcher-frontend = false/' $CONF

#run the arango shell
arangosh
var Planner = require("org/arangodb/cluster").Planner;
p = new Planner({numberOfDBservers:3, numberOfCoordinators:1});
var Kickstarter = require("org/arangodb/cluster").Kickstarter;
k = new Kickstarter(p.getPlan());
k.launch();
db._create("block",{numberOfShards:4});
db._create("sampleFormat",{numberOfShards:2});
db.block.ensureIndex({ type: "hash", fields: [ "sample","chr","start","end"], sparse: true });
db.sampleFormat.ensureIndex({ type: "hash", fields: [ "sampleID","varID","study","GT","AD_2"], sparse: true });

```


#create single entries to prime the indexes
```
for x in *json
do
 echo $x
 head -1 $x > ${x}.2
 /Applications/ArangoDB-CLI.app/Contents/MacOS/arangoimp --file ${x}.2 --type json --collection ${x/.json/} 
 rm ${x}.2
done
```


#Load full collections
```
arangoimp --file "block.json" --type json --collection block --progress true
arangoimp --file "sampleFormat.json" --type json --collection sampleFormat --progress true 
arangosh



```
