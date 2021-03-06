#!/bin/bash
################################################################################

# PARAMETERS
TARGETLIST=$1
INDIR=$2
ROOTDIR=$3
PHENO=$4
USE_WEIGHTS=$5
NPERM=$6
MAXPERM=$7 #used to be 1e10 ... long run time for a few jobs.
NONSIG=$8
jid=$9

if [ ! -f "$TARGETLIST" ]; then
    echo "Target file does not exist"
    exit
fi

if [ ! -f "$PHENO" ]; then
    echo "Phenotype file does not exist"
    exit
fi

if [ ! -d "$INDIR" ]; then
    echo "Directory with target files does not exist"
    exit
fi

if [ "$USE_WEIGHTS" != "TRUE" ] && [ "$USE_WEIGHTS" != "FALSE" ]; then
    echo "Use weights needs to be TRUE or FALSE"
    exit
fi
    
# CONFIG PARAMETERS
targetext=".vcf"

# INTERNAL PARAMETERS
outdir=${ROOTDIR}/output
jobdir=${ROOTDIR}/jobs
sge_logdir=${ROOTDIR}/log
sge_options="-V -cwd -o ${sge_logdir} -e ${sge_logdir} -q all.q"
bindir=$(dirname $0)
progname=$(basename $0 .bash)

# Create output directories
if ! mkdir -p ${ROOTDIR} ; then
    echo "Cannot create output directory"
    exit
fi

mkdir -p ${jobdir}
mkdir -p ${sge_logdir}
mkdir -p ${outdir}

RID=0
while read target
do
    # Find input file
    targetfile=${INDIR}/${target}${targetext}
    if [ ! -f ${targetfile} ] ; then
	echo "$(basename $0): WARNING -- File for ${target} not present in ${INDIR}."
	continue
    fi
    
    # Write SGE job to file
    let RID=RID+1
    echo "$(basename $0): Preparing ${target} for submission"
    genofile=${outdir}/${target}.geno
    phenofile=${outdir}/${target}.pheno
    weightfile=${outdir}/${target}.weight
    samplefile=${outdir}/${target}.sample
    snpfile=${outdir}/${target}.snpfile

    
    cat > ${jobdir}/${RID}.job <<EOF
$bindir/vcf2rr.py ${targetfile} ${PHENO} ${genofile} ${phenofile} ${weightfile} ${samplefile} ${snpfile}
Rscript $bindir/run_rr.r ${bindir} ${outdir} ${target} ${USE_WEIGHTS} ${NPERM} ${MAXPERM} ${NONSIG} > ${outdir}/${target}.rrout 2> ${outdir}/${target}.R.log
egrep "^${target}\," ${outdir}/${target}.rrout > ${outdir}/${target}.rrline
EOF
    chmod 755 ${jobdir}/${RID}.job
done < ${TARGETLIST}

# Prepare and execute SGE array job

cat > ${ROOTDIR}/submit_jobs.${jid}.bash << EOT
#!/bin/bash
#$ ${sge_options} -N ${jid}
${jobdir}/\$SGE_TASK_ID.job
EOT

chmod 755 ${ROOTDIR}/submit_jobs.${jid}.bash
qsub -t 1-${RID} ${sge_options} ${ROOTDIR}/submit_jobs.${jid}.bash
echo "TARGET,NMARKERS,PVALUE,NPERM,NONSIGNCOUNT" > ${ROOTDIR}/rr_results.txt
echo "cat ${outdir}/*.rrline >> ${ROOTDIR}/rr_results.txt" | qsub ${sge_options} -hold_jid ${jid} -N rrm$RANDOM
echo "Output will be in ${ROOTDIR}"