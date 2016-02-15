Requires the following perl modules:
```
Scalar::Util
```

Get input files
```
wget -O NA12878.chr22.g.vcf.gz https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/gvcfs/NA12878.chr22.g.vcf.gz
wget -O NA12891.chr22.g.vcf.gz https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/gvcfs/NA12891.chr22.g.vcf.gz
wget -O NA12892.chr22.g.vcf.gz https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/gvcfs/NA12892.chr22.g.vcf.gz

```
#Start Mongodb (db version v3.0.4)

```
sudo mongod
#change terminal and start the import process

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



#Import the full JSON
```
mongoimport -d challenge2 -c block block.json --drop
mongoimport -d challenge2 -c sampleFormat sampleFormat.json --drop
```

# add indexes to collections
```
mongo challenge2 --eval 'db.block.ensureIndex({ sample: 1 })'
mongo challenge2  --eval 'db.block.ensureIndex({ chr: 1 })'
mongo challenge2  --eval 'db.block.ensureIndex({ start: 1 })'
mongo challenge2  --eval 'db.block.ensureIndex({ end: 1 })'
mongo challenge2  --eval 'db.sampleFormat.ensureIndex({ sampleID: 1 })'
mongo challenge2  --eval 'db.sampleFormat.ensureIndex({ study: 1 })'
mongo challenge2  --eval 'db.sampleFormat.ensureIndex({ GT: 1 })'
mongo challenge2 --eval 'db.sampleFormat.ensureIndex({ AD_2: 1 })'
```


#Build your queries
```
#strategy based from https://www.youtube.com/watch?v=0YFcYoxlB74

#Get heterozygous variants in NA12878i
 var hets = db.sampleFormat.aggregate([{ $match: {$and : [{ "GT": { $in: ["0/1", "0|1"] } },{"_id.sample" : "NA12878i"}]} }])
 var hets_detail = hets.next() 

 var regions = 


```