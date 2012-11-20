#!/usr/bin/env python

import sys
import re

def isoformCsqToPolyPhenWeight(pos, csq):
    """ Return Polyphen weight from CSQ tag """
    
    isoforms = csq.split('+')
    probs = []
    preds = []
    muts = []
    weight_str = ""
    for iso in isoforms:
        m = re.search('\:(?P<mut>[A-Z]+\>[A-Z]+)\:.*PolyPhen,(?P<pred>[A-Za-z_]+)\((?P<prob>[0-9\.]+)\)',  iso)
        if m:
            probs.append(m.group('prob'))
            preds.append(m.group('pred'))
            muts.append(m.group('mut'))
    w = "0.5"
    if probs: 
        w = max(probs)
    return "%s %s\n" % (pos, w)
    
def do_flip(info):
    """ Return whether to flip REF with ALT allele values. """
    m = re.search('AN=([0-9]+)\;AC=([0-9]+)\;', info)
    an, ac = float(m.group(1)), float(m.group(2))
    return ac/an > 0.5
    #dp4 = [x for x in info.split(";") if x[0:4] == "DP4="]
    #dp4v = [int(x) for x in dp4[0].split("=")[1].split(",")]
    #refc, altc = float(dp4v[0]+dp4v[1]), float(dp4v[2]+dp4v[3])
    #return altc > refc

def convertGenotypes(pos, genotypes, info, samples):
    
    geno_str = ""
    flip = do_flip(info)
    for i in range(len(genotypes)):
        sample_id = samples[i]
        genotype = genotypes[i]
        
        m = re.search('(?P<allele1>[01\.])([\|\/](?P<allele2>[01\.]))?\:', genotype)
        
        if m:
            g = (int(m.group('allele1')) if not flip else (1 - int(m.group('allele1'))))
            if m.group('allele2'):
                g +=  (int(m.group('allele2')) if not flip else (1 - int(m.group('allele2'))))
            geno_str += "%s %s %s\n" % (sample_id, pos, g)
        else:
            print "%s: Cannot parse genotype %s at position %s" % (__file__, genotype, pos)
    return geno_str

if __name__ == "__main__":

    vcf_file = sys.argv[1]
    weight_outfile = sys.argv[2]
    geno_outfile = sys.argv[3]
    weight_str = ""
    geno_str = ""
    seen = []
    lines = [x.strip().split("\t") for x in open(vcf_file).readlines() if x[0:2] != '##']
    samples = lines[0][9:]
    for f in lines[1:]:
        chrom, pos, csq, genotypes = f[0], f[1], f[2], f[3:]
        chrom = f[0]
        pos = f[1]
        csq = f[7]
        genotypes = f[9:]
        if not pos in seen:
            weight_str += isoformCsqToPolyPhenWeight(pos, csq)
            geno_str += convertGenotypes(pos, genotypes, csq, samples)
        else:
            print "%s: Skipping duplicate SNP at position %s:%s in file %s" % (__file__, chrom, pos, vcf_file)
        seen.append(pos)
    of = open(weight_outfile, "w")
    print >> of, weight_str,
    of.close()
    of = open(geno_outfile, "w")
    print >> of, geno_str,
    of.close()
