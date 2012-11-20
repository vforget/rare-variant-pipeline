args <- commandArgs(trailingOnly = TRUE)
bindir <- args[1]
indir <- args[2]
target <- args[3]
use.weights <- as.logical(args[4])
nperm <- as.double(args[5])
nperm.max <- as.double(args[6])
mincounts <- as.double(args[7])

source(paste(bindir, "RR.r", sep="/"))
path <- paste(indir, target, sep="/")

genos <- read.table(paste(path, ".geno", sep=""), header=F)
pheno <- read.table(paste(path, ".pheno", sep=""), header=F, na.strings="-9")
weights <- read.table(paste(path, ".weight", sep=""), header=F)

x <- as.matrix(genos)
y <- as.matrix(pheno)
z <- as.matrix(weights)

x <- subset(x, !is.na(y))
y <- subset(y, !is.na(y))

if (use.weights){
  z <- as.matrix(weights)
}else{
  z <- matrix(1, nrow=length(z))
}

print(paste(length(x[,1]), length(x[1,]), length(y[,1]), length(z[,1])))
print(missing(x))
print(is.finite(x))
r <- RR(x, y, scale=z, npermutation=nperm, npermutation.max=nperm.max, min.nonsignificant.counts=mincounts)

write("TARGET,NMARKERS,PVALUE,NPERM,NONSIGNCOUNT", file="")
write(paste(target,  length(x[1,]), r$pvalue.empirical, r$total.permutation, r$nonsignificant.counts, sep=","), file="")
