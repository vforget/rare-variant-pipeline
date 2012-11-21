#!/bin/bash

usage()
{
cat << EOF
usage: $(basename $0) options

Run the RVA pipeline.

EXAMPLE:

run_pipeline.sh [-h] [-r file -t file -v dir -p file -x file] [options]

-h                  Show this message

Primary options:
-r    [filename]    Regions file (required).
-t    [filename]    Target file (required).
-v    [directory]   Source directory with genotype files in VCF format (required).
-p    [file]        Phenotype file (required).
-x    [file]        Parameter file (required).
-c    [file]        Covariates file (optional).
EOF
}



check_dir () {
    if [ -d $1 ]; then
    echo "Directory $1 already exists. Please run pipeline from a new project directory."
    exit
fi
}

REGION_FILE=
TARGET_FILE=
VCF_DIR=
PHENO_FILE=
PARAM_FILE=
COVAR_FILE="None"

while getopts hr:t:v:p:x:c: OPTION
do
    case $OPTION in
	h)
	    usage
	    exit
	    ;;
	r)
	    REGION_FILE=$(readlink -f $OPTARG)
	    
	    if [[ ! -r ${REGION_FILE} ]]; then
		echo "${progname} -- Region file non-existent or non-readable"
		exit 1
	    fi
	    ;;
	t)
	    TARGET_FILE=$(readlink -f $OPTARG)
	    if [[ ! -r ${TARGET_FILE} ]]; then
		echo "${progname} -- Target file non-existent or non-readable"
		exit 1
	    fi
	    ;;
	p)
	    PHENO_FILE=$(readlink -f $OPTARG)
	    if [[ ! -r ${PHENO_FILE} ]]; then
		echo "${progname} -- Phenotype file non-existent or non-readable"
		exit 1
	    fi
	    ;;
	x)
	    PARAM_FILE=$(readlink -f $OPTARG)
	    if [[ ! -r ${PARAM_FILE} ]]; then
		echo "${progname} -- Parameter file non-existent or non-readable"
		exit 1
	    fi
	    ;;
	c)
	    COVAR_FILE=$(readlink -f $OPTARG)
	    if [[ ! -r ${COVAR_FILE} ]]; then
		echo "${progname} -- Covariate file non-existent or non-readable"
		exit 1
	    fi
	    ;;
	v)
	    VCF_DIR=$(readlink -f $OPTARG)
	    if [[ ! -d ${VCF_DIR} ]]; then
		echo "${progname} -- Source VCF directory is non-existent"
		exit 1
	    fi
	    ;;
	\?)
	    usage
	    exit
	    ;;
    esac
done

if [[ -z $REGION_FILE ]] || [[ -z $TARGET_FILE ]] || [[ -z $PHENO_FILE ]] || [[ -z $PARAM_FILE ]] || [[ -z $VCF_DIR ]]
then
    echo -e "The pipeline requires five paramenters.\n\n"
    usage
    exit 1
fi

echo "** Command line parameters **"
echo -e "REGION_FILE = $REGION_FILE"
echo -e "TARGET_FILE = $TARGET_FILE"
echo -e "PHENO_FILE = $PHENO_FILE"
echo -e "VCF_DIR = $VCF_DIR"
echo -e "PARAM_FILE = $PARAM_FILE"
echo -e "COVAR_FILE = $COVAR_FILE"
echo "** Parameter from file **"
cat $PARAM_FILE

source $PARAM_FILE
bindir=$(readlink -f $(dirname $0))

target_dir=targets
target_vcfdir=tvcf
window_dir=windows

vtout=vt.output
skatout=skat.output
rrout=rr.output

check_dir $target_dir
check_dir $target_vcfdir
check_dir $window_dir

window_file=windows.txt

# STEP 1 -- Regions to Targets
echo "** Grouping regions by target **"
mkdir -p $target_dir && cd $target_dir
${bindir}/01_split.py $REGION_FILE
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

vt_jid=vt$RANDOM
skat_jid=skat$RANDOM
rr_jid=rr$RANDOM

# Run VT
if [ "$VT_RUN" == "Y" ]; then
    echo "** VT **"
    $bindir/04_vt.bash $TARGET_FILE $target_vcfdir/output/ $vtout/ $PHENO_FILE $vt_jid
fi

# Run SKAT
if [ "$SKAT_RUN" == "Y" ]; then
    echo "** SKAT **"
    $bindir/05_skat.bash $TARGET_FILE $target_vcfdir/output/ $skatout/ $PHENO_FILE $SKAT_USE_WEIGHTS $SKAT_TRAIT_TYPE $SKAT_RESAMP_SIZE $skat_jid
    
fi

# Run RR
if [ "$RR_RUN" == "Y" ]; then
    echo "** RR **"
    $bindir/06_rr.bash $TARGET_FILE $target_vcfdir/output/ $rrout/ $PHENO_FILE $RR_USE_WEIGHTS $RR_NPERM $RR_MAXPERM $RR_NONSIG $rr_jid
fi

# Clean up
echo "rm -Rf windows/ tvcf/" | qsub -V -cwd -q all.q -N rm$RANDOM -hold_jid "$vt_jid,$skat_jid,$rr_jid"
