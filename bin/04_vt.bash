#!/bin/bash
################################################################################

# PARAMETERS
TARGETLIST=$1
INDIR=$2
ROOTDIR=$3
PHENOFILE=$4
JID=$5

if [ ! -f "$TARGETLIST" ]; then
    echo "Target file does not exist"
    exit
fi

if [ ! -d "$INDIR" ]; then
    echo "Directory with target files does not exist"
    exit
fi

if [ ! -f "$PHENOFILE" ]; then
    echo "Phenotype file does not exist"
    exit
fi


# CONFIG PARAMETERS
targetext=".vcf"
genoext=".geno"
weightext=".weight"
VT_PERM_NUM=1000
SGE_CORES=0

# INTERNAL PARAMETERS
outdir=${ROOTDIR}/output
jobdir=${ROOTDIR}/jobs
logdir=${ROOTDIR}/log
sge_logdir=${ROOTDIR}/sge_log
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
mkdir -p ${logdir}
mkdir -p ${outdir}

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
    genofile=${outdir}/${target}.geno
    weightfile=${outdir}/${target}.weight

    cat > ${jobdir}/${RID}.job <<EOF
$bindir/vcf2vt.py ${targetfile} ${weightfile} ${genofile}
Rscript ${bindir}/vt.r \
    -p ${VT_PERM_NUM} \
    -n ${SGE_CORES} \
    -a ${PHENOFILE} \
    -b ${weightfile} \
    -c ${genofile} \
    > ${outdir}/${target}.vtout \
    2> ${outdir}/${target}.R.log
if [[ \$(cat ${outdir}/${target}.R.log) =~ 'Execution halted' ]]; then
    echo "Skipping ${target}: R script crashed."
    exit
fi
NMARKERS=\$(cut -f 2 -d ' ' ${genofile} | sort | uniq | wc -l)
PHENO=\$(echo "${PHENOFILE}" | gawk -F/ '{print \$NF}'| gawk -F. '{print \$1}')
echo -n "${target},\${NMARKERS},\${PHENO}," > ${outdir}/${target}.vtline
sed -n '/^p-values/,\$p' ${outdir}/${target}.vtout | \
    tail -n +3 | \
    gawk 'BEGIN{OFS=","}{print \$2,\$3,\$4,\$5,\$6,\$7,\$8,\$9,\$10,\$11}' >> ${outdir}/${target}.vtline;

# $bindir/vt.bash ${INDIR} ${target} ${outdir} ${PHENOFILE}
EOF
    chmod 755 ${jobdir}/${RID}.job

done < ${TARGETLIST}
# Prepare and execute SGE array job

cat > ${ROOTDIR}/submit_jobs.${JID}.bash << EOT
#!/bin/bash
#$ ${sge_options} -N ${JID}
${jobdir}/\$SGE_TASK_ID.job
EOT
chmod 755 ${ROOTDIR}/submit_jobs.${JID}.bash
qsub -t 1-${RID} ${sge_options} ${ROOTDIR}/submit_jobs.${JID}.bash
echo "TARGET,N_Markers,PHENO,T1,T1P,T5,T5P,WE,WEP,VT,VTP,NEGSTAT.B.01,NEGSTAT.B.05" > \
    ${ROOTDIR}/vt_results.txt
echo "cat ${outdir}/*.vtline >> ${ROOTDIR}/vt_results.txt" | qsub ${sge_options} -hold_jid ${JID} -N vtm$RANDOM