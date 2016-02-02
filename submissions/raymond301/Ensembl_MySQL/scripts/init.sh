#!/usr/bin/env bash

## Initally created and tested on Mac OSx 10.7.5 (1.8 GHz & 8 GB Mem)

# Check if file exists
if [ -e "1KG.chr22.anno.infocol.vcf.gz" ];
then
    gunzip 1KG.chr22.anno.infocol.vcf.gz;
else
   wget https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/vcfs/1KG.chr22.anno.infocol.vcf.gz --no-check-certificate
fi
if test -f "1KG.chr22.anno.infocol.vcf"; then echo "The VCF File Exists"; else echo "No 1K Genome VCF"; exit 1; fi


if [ -e "phase1_integrated_calls.20101123.ALL.panel" ];
then
    echo ""
else
    wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/release/20110521/phase1_integrated_calls.20101123.ALL.panel
fi
if test -f "phase1_integrated_calls.20101123.ALL.panel"; then echo "The Panel File Exists"; else echo "No 1K Genome PANEL"; exit 1; fi


if [ -e "README.sample_cryptic_relations" ];
then
    echo ""
else
    wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/release/20110521/README.sample_cryptic_relations
fi
if test -f "README.sample_cryptic_relations"; then echo "The Relations File Exists"; else echo "No 1K Genome Relations"; exit 1; fi


#Check execute script - timer



#Remove downloaded File