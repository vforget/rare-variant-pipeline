TARGET_VCF_DIR=$1
target=$2
WINSIZE=$3
STEPSIZE=$4
MIN_WINSIZE=$5
WINDOW_OUTDIR=$6

progname=$(basename $0 .bash)

lc=$(grep -v '^#' ${TARGET_VCF_DIR}/${target}.vcf | wc -l)
grep '^#' ${TARGET_VCF_DIR}/${target}.vcf > ${WINDOW_OUTDIR}/${target}.header.vcf
wid=0

let rend=$lc-$STEPSIZE
for i in $(seq 0 ${STEPSIZE} ${rend})
do
    let wid=$wid+1
    wstart=$i
    let wend=$i+$WINSIZE
    if [ "$wend" -ge "$lc" ]; then
	wend=$lc
    fi
    let wlen=$wend-$wstart
    cat ${WINDOW_OUTDIR}/${target}.header.vcf > ${WINDOW_OUTDIR}/${target}.${wid}.vcf
    grep -v '^#' ${TARGET_VCF_DIR}/${target}.vcf | head -n $wend | tail -n ${wlen} >> ${WINDOW_OUTDIR}/${target}.${wid}.vcf
done

sc=$(wc -l ${WINDOW_OUTDIR}/${target}.${wid}.vcf | cut -f 1 -d ' ')

if [ "$wid" -gt "1" ] && [ $sc -lt $MIN_WINSIZE ]; then
    let pid=$wid-1
    echo "$progname: Last window ($wid) SNP count ($sc) is below theshold ($MIN_WINSIZE), mergin to previous window (${pid})"
    grep -v '^#' ${WINDOW_OUTDIR}/${target}.${wid}.vcf >> ${WINDOW_OUTDIR}/${target}.${pid}.vcf
    rm ${WINDOW_OUTDIR}/${target}.${wid}.vcf
fi

rm ${WINDOW_OUTDIR}/${target}.header.vcf