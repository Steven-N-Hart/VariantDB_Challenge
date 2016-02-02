#!/usr/bin/env bash

## Initally created and tested on Mac OSx 10.7.5 (1.8 GHz & 8 GB Mem)

# wget https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/vcfs/1KG.chr22.anno.infocol.vcf.gz --no-check-certificate

# Check if file exists
if [ -e "1KG.chr22.anno.infocol.vcf.gz" ]; then gunzip 1KG.chr22.anno.infocol.vcf.gz; fi
if test -f "1KG.chr22.anno.infocol.vcf"; then echo "The File Exists"; else echo "No 1K Genome VCF"; exit 1; fi

#Check execute script - timer

#Remove downloaded File