Requires the following perl module:
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
```
time bgzip -dc 1KG.chr22.anno.infocol.vcf.gz |perl scripts/VCF2Arango.pl -VCF - -study 1000Genomes 

real	53m28.825s
user	53m21.416s
sys	0m21.003s

```

Transform the cryptic relatedness file into JSON
```
perl scripts/parseRelatedness.pl -i README.sample_cryptic_relations
```

The last transformation is for the population descriptions
```

```