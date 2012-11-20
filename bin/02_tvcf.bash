#!/bin/bash
################################################################################
#
# Prepare input for VT from target regions of a VCF file.
#
# Example:
# ~/share/0812-exome-pipeline/bin/02_run_tvcf.bash \
#    genelist.txt \
#    ~/share/vince.forgetta/UK10K_COHORT/exome/data/ \
#    ~/tempdata/UK10K_COHORT/exome/tvcf \
#    ~/share/UK10K_COHORT/REL-2011-12-01/v4
#    > 02_run_tvcf.log
#
# Where parameters are:
#
#    genelist.txt: List of TARGET names.
#    ~/share/vince.forgetta/UK10K_COHORT/exome/data/: Directory with TARGET files, 
#    named TARGET.bed
#    ~/tempdata/UK10K_COHORT/exome/tvcf Output directory
#    ~/share/UK10K_COHORT/REL-2011-12-01/v4: Where chromosome VCF files are stored
#
# NOTE:
# Assume VCF files start with chrom # i.e. 10.*.vcf.gz

# REQUIRED PARAMETERS
NAME_LIST_FILE=$1
TARGETDIR=$2
OUTDIR=$3
VCF_DIR=$4
MAF=$5

if [ ! -f "$NAME_LIST_FILE" ]; then
    echo "Target file does not exist"
    exit
fi

if [ ! -d "$TARGETDIR" ]; then
    echo "Directory with target files does not exist"
    exit
fi

if [ ! -d "$VCF_DIR" ]; then
    echo "Directory with VCF files does not exist"
    exit
fi

# INTERNAL PARAMETERS
tabix_outdir=${OUTDIR}/output
target_ext=".txt"

# OUTPUT DIRECTORIES
jobdir=${OUTDIR}/jobs
logdir=${OUTDIR}/log
sge_logdir=${OUTDIR}/sge_log

# OTHER INTERNAL PARAMETERS
sge_options="-V -cwd -o ${sge_logdir} -e ${sge_logdir} -q all.q"
bindir=$(dirname $0)
progname=$(basename $0 .bash)

# Create output directories
if ! mkdir -p ${OUTDIR} ; then
    echo "Cannot create output directory"
    exit
fi

mkdir -p $jobdir
mkdir -p $sge_logdir
mkdir -p ${tabix_outdir}
mkdir -p ${logdir}

RID=0
while read target
do
    # Find input file
    regionfile=${TARGETDIR}/${target}${target_ext}
    if [ ! -f ${regionfile} ] ; then
	echo "${progname}: Skipping ${target} -- File not present in ${TARGETDIR}."
	continue
    fi

    # Write SGE job to file
    let RID=RID+1
    echo "${progname}: Preparing ${target} for submission to Grid Engine"
    cat > ${jobdir}/${RID}.job <<EOF
$bindir/tabix.bash $regionfile ${VCF_DIR} ${tabix_outdir}/${target}.vcf ${MAF} &> ${logdir}/${target}.log
EOF
    
    chmod 755 ${jobdir}/${RID}.job
done < ${NAME_LIST_FILE}

# Prepare and execute SGE array job
echo "r${progname}: Executing SGE array job"
JID="target$RANDOM"
cat > ${OUTDIR}/submit_jobs.${JID}.bash << EOT
#!/bin/bash
#$ ${sge_options} -N ${JID}
${jobdir}/\$SGE_TASK_ID.job
EOT
chmod 755 ${OUTDIR}/submit_jobs.${JID}.bash
qsub -t 1-${RID} ${sge_options} ${OUTDIR}/submit_jobs.${JID}.bash