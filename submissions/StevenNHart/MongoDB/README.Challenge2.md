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
	perl scripts/gVCF_split.pl -i ${x/g.vcf.gz/gq20.g.vcf}|perl scripts/gVCF2Mongo.pl -v - -s 1000Genomes
	rm ${x/g.vcf.gz/gq20.g.vcf}
done

```

# TODO: Install sharded cluster

#create single entries to prime the indexes
```
for x in *json
do
 echo $x
 head -1 $x > ${x}.2
 mongoimport -d test -c ${x/.json/} ${x}.2 
 rm ${x}.2
done
```

# add indexes to collections
```
mongo --eval 'db.block.ensureIndex({ sample: 1 })'
mongo --eval 'db.block.ensureIndex({ chr: 1 })'
mongo --eval 'db.block.ensureIndex({ start: 1 })'
mongo --eval 'db.block.ensureIndex({ end: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ sampleID: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ study: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ GT: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ AD_2: 1 })'
```
