
# Build a sharded cluster 

|IP-address|hostname|
|10.0.0.20|hn0-varian|
|10.0.0.18|wn1-varian|
|10.0.0.14|wn2-varian|
|10.0.0.10|wn3-varian|

```
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

#Filter the gVCFs to contain genotype quality values > 20 and then create JSON files
```
rm *json
time for x in *gz
do
        echo ${x/g.vcf.gz/gq20.g.vcf}
        zcat $x|perl scripts/FormatFilter.pl - > ${x/g.vcf.gz/gq20.g.vcf}
        perl scripts/gVCF_split.pl -i ${x/g.vcf.gz/gq20.g.vcf}|perl scripts/gVCF2Mongo.pl -v - -s 1000Genomes
        rm ${x/g.vcf.gz/gq20.g.vcf}
done
#real    0m0.923s
#user    0m1.232s
#sys     0m0.036s
```

# Create single entries to prime the indexes
```
time for x in sampleFormat.json block.json
do
 echo $x
 head -1 $x > ${x}.2
 mongoimport -d test --drop -c ${x/.json/} ${x}.2
 rm ${x}.2
done
#real    0m0.826s
#user    0m0.016s
#sys     0m0.000s
```
#Add indexes to collections
```
mongo --eval 'db.block.ensureIndex({ "sample": 1, "chr": 1, "pos": 1, "study": 1})'
mongo --eval 'db.sampleFormat.ensureIndex({ GT: 1 })'
mongo --eval 'db.sampleFormat.ensureIndex({ AD_2: 1 })'
```

#Import the full JSON
```
time mongoimport  -c block block.json 
#real    0m0.774s
#user    0m0.432s
#sys     0m0.040s

time mongoimport -c sampleFormat sampleFormat.json -j 50
#real    0m0.355s
#user    0m0.184s
#sys     0m0.020s
```

#Run your queries
```
time mongo  < scripts/challenge2.js > out
#real    0m21.541s
#user    0m0.316s
#sys     0m0.040s

```
#Stats:
```
block: "storageSize" : 876544
sampleFormat:   "storageSize" : 364544
```


