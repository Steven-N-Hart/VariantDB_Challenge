Requires the following perl modules:
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
* I gave the VCF a study name to merge with the sample names so I can prevent conflicts in the namespace when adding new samples
* I created a varID key by combining "chrom:pos:ref:alt" so I know what variant position I am talking about
```
time bgzip -dc 1KG.chr22.anno.infocol.vcf.gz |perl scripts/VCF2Arango.pl -VCF - -study 1000Genomes 

real	38m15.276s
user	38m6.785s
sys	  0m22.358s

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
```
#Start Arango
/Applications/ArangoDB-CLI.app/Contents/MacOS/arangod 
#change terminal and start the import process

```


#create single entries to prime the indexes
```
for x in *json
do
 echo $x
 head -1 $x > ${x}.2
 /Applications/ArangoDB-CLI.app/Contents/MacOS/arangoimp --file ${x}.2 --type json --collection ${x/.json/} --create-collection true
 rm ${x}.2
done
```

# add indexes to collections
```
/Applications/ArangoDB-CLI.app/Contents/MacOS/arangosh
db.info.ensureIndex({ type: "hash", fields: [ "Effect_Impact"], sparse: true });
db.info.ensureIndex({ type: "hash", fields: [ "ExAC_Info_AF" ] });
db.info.ensureIndex({ type: "hash", fields: [ "SAVANT_IMPACT" ], sparse: true });
db.sampleFormat.ensureIndex({ type: "hash", fields: [ "sampleID" ] });
exit
```

#Load full collections
```
/Applications/ArangoDB-CLI.app/Contents/MacOS/arangoimp --file "cryptic.json" --type json --collection cryptic --progress true 
/Applications/ArangoDB-CLI.app/Contents/MacOS/arangoimp --file "populations.json" --type json --collection populations --progress true 
/Applications/ArangoDB-CLI.app/Contents/MacOS/arangoimp --file "info.json" --type json --collection info --progress true
/Applications/ArangoDB-CLI.app/Contents/MacOS/arangoimp --file "sampleFormat.json" --type json --collection sampleFormat --progress true 
/Applications/ArangoDB-CLI.app/Contents/MacOS/arangosh
```
#Formulate Queries
```
LET sampleLIST = (
	LET samples =(FOR sample IN cryptic
    FILTER sample.Population != "ASW" && sample.Relationship != "Sibling"
    COLLECT s1 = sample.Sample_1, s2 = sample.Sample_2 
    RETURN [s1,s2]
    )
	RETURN(FLATTEN(samples,2))
)

LET sampleCounts = (
FOR format IN sampleFormat
    FILTER format.GQ >= 30 && (format.GT == '0|1' || format.GT == '0/1') && format.sampleID IN sampleLIST[0]
        FOR info in info
            FILTER format.varID == info._key
            FILTER info.Effect_Impact IN ["HIGH","MODERATE"]
            FILTER info.AF < 0.1
            RETURN format.sampleID 
)

LET sampleSummaryCounts = (
    for u in sampleCounts
        COLLECT sample = u WITH COUNT INTO length
        RETURN { sample: sample, length: length } 
)

LET majorPop = (
    FOR pop IN populations 
        RETURN DISTINCT pop.Pop2
 )
 
LET popCounts = (
    FOR u IN sampleSummaryCounts
        FOR pop IN populations 
            FILTER u.sample == pop.SAMPLE
            COLLECT sample = u.sample, length = u.length, Pop = pop.Pop2 
            RETURN {length:length, pop:Pop}
)

FOR x IN majorPop
    FOR y IN popCounts
        FILTER x == y.pop
        COLLECT  pop = x 
        AGGREGATE len = SUM(y.length)
        RETURN {"P":pop,"c":len}

 

```


