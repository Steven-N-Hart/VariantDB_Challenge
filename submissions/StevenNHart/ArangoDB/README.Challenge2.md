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
db.sampleFormat.ensureIndex({ type: "hash", fields: [ "chr", "start","sampleID","study","GT","AD_2"], sparse: true });
exit

```


#Load full collections
```
arangoimp --file "block.json" --type json --collection block --progress true --create-collection true
arangoimp --file "sampleFormat.json" --type json --collection sampleFormat --progress true --create-collection true
arangosh

```

#Run queries
```

#NOT YET COMPLETE

FOR sample in sampleFormat
    FILTER sample.sampleID == "NA12878i" 
    FILTER sample.GT IN ['0/1','1/1']
    FOR bloc IN block
        FILTER sample.chr == bloc.chr && sample.start >= bloc.start && sample.start <= bloc.end && bloc.sampleID != "NA12878i"
        COLLECT variantS = sample.sampleID,
                variantsC = sample.chr,
                variantsP = sample.start,
                hRefS = bloc.sample,
                hRefF = bloc.format,
                hRefG = bloc.sampleFormat
                LIMIT 20
        RETURN [variantS, variantsC,variantsP,hRefS,hRefF,hRefG]

```
