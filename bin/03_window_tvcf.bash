#!/bin/bash

# Splits VCF file.
#
# Example:
# ~/share/0812-exome-pipeline/bin/03_run_window.bash \
#    genelist.txt \
#    ~/tempdata/UK10K_COHORT/exome/tvcf \
#    ~/tempdata/UK10K_COHORT/exome/window \
#    10 \
#    5 \
#    4 \
#    > 03_run_window.log
#
# Where parameters are:
#
#    genelist.txt: List of TARGET names.
#    ~/share/vince.forgetta/UK10K_COHORT/exome/data/: Directory with TARGET files, 
#    named TARGET.vcf
#    ~/tempdata/UK10K_COHORT/exome/tvcf Input directory of VCF files
#    ~/tempdata/UK10K_COHORT/exome/window Output directory
#    10 Window size
#    5 Step size
#    5 Min window size. Trailing window with fewer SNPs will be merged with previous window.
#
# NOTE:
# Assume VCF files are names TARGET.vcf

NAME_LIST_FILE=$1
TARGET_VCF_DIR=$2
OUTDIR=$3
WINSIZE=$4
STEPSIZE=$5
MIN_WINSIZE=$6

if [ ! -f "$NAME_LIST_FILE" ]; then
    echo "Target file does not exist"
    exit
fi

if [ ! -d "$TARGET_VCF_DIR" ]; then
    echo "Directory with target VCF files does not exist"
    exit
fi

if [ "$STEPSIZE" -gt "$WINSIZE" ]; then
    echo "Step size cannot be larger than window size"
    exit
fi

if [ "$MIN_WINSIZE" -gt "$WINSIZE" ]; then
    echo "Minimum window size cannot be larger than window size"
    exit
fi

bindir=$(dirname $0)
progname=$(basename $0 .bash)
jobdir=${OUTDIR}/jobs
logdir=${OUTDIR}/log
window_outdir=${OUTDIR}/output
sge_logdir=${OUTDIR}/sge_log
sge_options="-V -cwd -o ${sge_logdir} -e ${sge_logdir} -q all.q"

if ! mkdir -p ${OUTDIR} ; then
    echo "Cannot create output directory"
    exit
fi

mkdir -p ${jobdir}
mkdir -p ${logdir}
mkdir -p ${sge_logdir}
mkdir -p ${window_outdir}

RID=0
while read target
do
    let RID=RID+1
    echo "${progname}: Preparing ${target} for submission"
    cat > ${jobdir}/${RID}.job <<EOF
$bindir/window.bash $TARGET_VCF_DIR $target $WINSIZE $STEPSIZE $MIN_WINSIZE $window_outdir
EOF
    chmod 755 ${jobdir}/${RID}.job
done < ${NAME_LIST_FILE}

# Prepare and execute SGE array job
JID="r${progname}$RANDOM"
cat > ${OUTDIR}/submit_jobs.${JID}.bash << EOT
#!/bin/bash
#$ ${sge_options} -N ${JID}
${jobdir}/\$SGE_TASK_ID.job
EOT
chmod 755 ${OUTDIR}/submit_jobs.${JID}.bash
qsub -t 1-${RID} ${sge_options} ${OUTDIR}/submit_jobs.${JID}.bash
