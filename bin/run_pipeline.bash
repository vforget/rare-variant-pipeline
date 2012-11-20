#!/bin/bash

check_dir () {
    if [ -d $1 ]; then
    echo "Directory $1 already exists. Please run pipeline from a new project directory."
    exit
fi
}

REGION_FILE=$1
TARGET_FILE=$2
VCF_DIR=$3
PHENO_FILE=$4
PARAM_FILE=$5

if [ ! -f "$PARAM_FILE" ]; then
    echo "Parameter file not found."
    exit
fi

source $PARAM_FILE
bindir=$(readlink -f $(dirname $0))

target_dir=targets
target_vcfdir=tvcf
window_dir=windows

vtout=vt.target
skatout=skat.target
rrout=rr.target

#check_dir $target_dir
#check_dir $target_vcfdir
#check_dir $window_dir

window_file=windows.txt

# STEP 1 -- Regions to Targets
echo "** Grouping regions by target **"
mkdir -p $target_dir && cd $target_dir
${bindir}/01_split.py ../$REGION_FILE
cd ..

# STEP 2 -- Target VCF
echo "** Fetching SNPs by target **"
$bindir/02_tvcf.bash $TARGET_FILE $target_dir/ $target_vcfdir/ $VCF_DIR $MAF

# STEP 3 -- Window
if [ "$WIN_RUN" == "Y" ]; then
    echo "** Splitting targets into windows **" 
    $bindir/03_window_tvcf.bash $TARGET_FILE $target_vcfdir/output/ $window_dir/ $WIN_SIZE $WIN_STEP $WIN_MIN
    TARGET_FILE=$window_file
    target_vcfdir=$window_dir
fi

if [ "$VT_RUN" == "Y" ]; then
    echo "** VT **"
    $bindir/04_vt.bash $TARGET_FILE $target_vcfdir/output/ $vtout/ $PHENO_FILE
fi

if [ "$SKAT_RUN" == "Y" ]; then
    echo "** SKAT **"
    $bindir/05_skat.bash $TARGET_FILE $target_vcfdir/output/ $skatout/ $PHENO_FILE $SKAT_USE_WEIGHTS $SKAT_TRAIT_TYPE $SKAT_RESAMP_SIZE
    
fi

if [ "$RR_RUN" == "Y" ]; then
    echo "** RR **"
    $bindir/06_rr.bash $TARGET_FILE $target_vcfdir/output/ $rrout/ $PHENO_FILE $RR_USE_WEIGHTS $RR_NPERM $RR_MAXPERM $RR_NONSIG
fi
