library(SKAT)

args <- commandArgs(trailingOnly = TRUE)
indir <- args[1]
target <- args[2]
use.weights <- as.logical(args[3])
out_type <- args[4]


resampling <- 1000
path=paste(indir, target, sep="/")
genos = read.table(paste(path, ".geno", sep=""), header=F)
pheno = read.table(paste(path, ".pheno", sep=""), header=F, na.strings="-9")
weights = read.table(paste(path, ".weight", sep=""), header=F)

gm = as.matrix(genos)
p = as.matrix(pheno)
w = as.matrix(weights)

obj<-SKAT_Null_Model(p ~ 1, out_type=out_type, n.Resampling=resampling)

s <- FALSE
if (use.weights){
  s = SKAT(gm, obj, weights=w)
}else{
  s = SKAT(gm, obj)
}

rs <- Get_Resampling_Pvalue(s)
print(paste(target, s$param$n.marker, s$param$n.marker.test, s$p.value, s$param$liu_pval, rs$p.value, sep=","))
