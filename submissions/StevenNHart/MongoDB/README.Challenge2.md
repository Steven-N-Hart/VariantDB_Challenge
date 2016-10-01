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
time for x in *gz
do
	echo ${x/g.vcf.gz/gq20.g.vcf}
	zcat $x|perl scripts/FormatFilter.pl - > ${x/g.vcf.gz/gq20.g.vcf}
	perl scripts/gVCF_split.pl -i ${x/g.vcf.gz/gq20.g.vcf}|perl scripts/gVCF2Mongo.pl -v - -s 1000Genomes
	rm ${x/g.vcf.gz/gq20.g.vcf}
done

#real    0m0.969s
#user    0m1.232s
#sys     0m0.044s
```

# Create single entries to prime the indexes
```
time for x in sampleFormat.json block.json
do
 echo $x
 head -1 $x > ${x}.2
 mongoimport -d challenge2 -c ${x/.json/} ${x}.2 
 rm ${x}.2
done
#real    0m0.257s
#user    0m0.012s
#sys     0m0.004s

```
#Add indexes to collections
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

#Import the full JSON
```
time mongoimport -d challenge2 -c block block.json --drop
#2016-09-19T21:00:01.404+0000    imported 19263 documents
#real    0m1.078s
#user    0m0.300s
#sys     0m0.032s


time mongoimport -d challenge2 -c sampleFormat sampleFormat.json --drop
#real    0m1.138s
#user    0m0.168s
#sys     0m0.008s

```

#Run your queries
```
time mongo --quiet challenge2 < scripts/challenge2.js > out
#real    0m1.138s
#user    0m0.168s
#sys     0m0.008s
```

#Stats:
```
block: "storageSize" : 872448
sampleFormat:	"storageSize" : 360448
```
