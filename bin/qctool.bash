#!/bin/bash

regionfile=$1
chrom=7
target=$(basename ${regionfile} .txt)
infile=~/tempdata/TwinsUK_Imputed/bgen/chr${chrom}.bgen
outfile=${target}.gen

qctool=~/data/bin/qctool_v1.3-linux-x86_64/qctool
logfile=${target}.qctool.log

rm ${outfile} ${logfile}
touch ${outfile} ${logfile}

while read chrom rstart rend target
do
    ${qctool} -g ${infile} -omit-chromosome -incl-range ${rstart}-${rend} -og - >> ${outfile} 2>> ${logfile}
    
done < ${regionfile}