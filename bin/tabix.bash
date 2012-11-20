#!/bin/bash

## REQUIRED PARAMETERS
REGIONFILE=$1
VCF_DIR=$2
raw_vcf_file=$3
MAF=$4

# INTERNAL VARIABLES
export PATH=$PATH:/usr/local/tabix-0.2.5/
vcf_ext=".*.vcf.gz"

bindir=$(dirname $0)

touch ${raw_vcf_file}

RID=0
while read chrom start end name
do         
    region="${chrom}:${start}-${end}"
    
    # Find VCF file
    vcffile=$(ls ${VCF_DIR}/${chrom}${vcf_ext} | head -n 1)
    if [[ -z "$vcffile" ]]; then
	echo "Skipping ${name} for location ${region}: VCF file for chromosome ${chrom} is non-existent."
	continue
    fi

    if [ ! -f ${vcffile} ]; then
	echo "Skipping ${name} for location ${region}: VCF file for chromosome ${chrom} is non-existent."
	continue
    fi
    
    tabix_command="tabix"
    if [ "$RID"  == "0" ] ; then
	tabix_command="tabix -h"
    fi
    
    ${tabix_command} \
	${vcffile} \
	${region} \
	>> ${raw_vcf_file}
    let RID=RID+1   
done < ${REGIONFILE}

# Filter for MAF
awk "{ if (\$0 ~ /^#/) { print \$0 }else{ match(\$0, /AN=([0-9]+)\;AC=([0-9]+)/, a); if (a[2]/a[1] <= ${MAF}) print \$0} }" \
    ${raw_vcf_file} > ${raw_vcf_file}.maf${MAF}
# Remove duplicate SNPs
awk "{ if (\$0 ~ /^#/) { print \$0 }else{ seen[\$2]++; a[++count]=\$0; key[count]=\$2}} END {{for (i=1;i<=count;i++) if (seen[key[i]] == 1) print a[i]}}" ${raw_vcf_file}.maf${MAF} > ${raw_vcf_file}
rm ${raw_vcf_file}.maf${MAF}