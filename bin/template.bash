#!/bin/bash
################################################################################

# PARAMETERS
TARGETLIST=$1
INDIR=$2
OUTDIR=$3

# CONFIG PARAMETERS
targetext=".bed"

# INTERNAL PARAMETERS
jobdir=${OUTDIR}/jobs
logdir=${OUTDIR}/log
sge_logdir=${OUTDIR}/sge_log
sge_options="-V -cwd -o ${sge_logdir} -e ${sge_logdir} -q all.q"
bindir=$(dirname $0)
progname=$(basename $0 .bash)

# Create output directories
mkdir -p ${OUTDIR}
mkdir -p ${jobdir}
mkdir -p ${sge_logdir}
mkdir -p ${logdir}

RID=0
while read target
do
    # Find input file
    targetfile=${INDIR}/${target}${targetext}
    if [ ! -f ${targetfile} ] ; then
	echo "$(basename $0): Skipping ${target} -- Target file not present in ${INDIR}."
	continue
    fi
    
    # Write SGE job to file
    let RID=RID+1
    echo "$(basename $0): Preparing ${target} for submission"
    while read chrom start end name
    do
	region="${chrom}:${start}-${end}"
    done < ${regionfile}
    cat > ${jobdir}/${RID}.job <<EOF
??? SOME SCRIPT ???
EOF
    chmod 755 ${jobdir}/${RID}.job

done < ${TARGETLIST}

# Prepare and execute SGE array job
JID="$progname$RANDOM"
cat > ${OUTDIR}/submit_jobs.${JID}.bash << EOT
#!/bin/bash
#$ ${sge_options} -N ${JID}
${jobdir}/\$SGE_TASK_ID.job
EOT
chmod 755 ${OUTDIR}/submit_jobs.${JID}.bash
qsub -t 1-${RID} ${sge_options} ${OUTDIR}/submit_jobs.${JID}.bash
