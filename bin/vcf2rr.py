#!/usr/bin/env python

# Assumes vcf files has 9 columns before genotype data, and that column 8 is the INFO column

import sys
import re

def isoformCsqToPolyPhenWeight(csq):
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
    return w

def do_flip(info):
    m = re.search('AN=([0-9]+)\;AC=([0-9]+)\;', info)
    an, ac = float(m.group(1)), float(m.group(2))
    return ac/an > 0.5
    #dp4 = [x for x in info.split(";") if x[0:4] == "DP4="]
    #dp4v = [int(x) for x in dp4[0].split("=")[1].split(",")]
    #refc, altc = float(dp4v[0]+dp4v[1]), float(dp4v[2]+dp4v[3])
    #return (altc * 1.5) > refc
if __name__ == "__main__":

    # PARAMETERS
    vcf_file = sys.argv[1]
    pheno_file = sys.argv[2]
    geno_outfile = sys.argv[3]
    pheno_outfile = sys.argv[4]
    weight_outfile = sys.argv[5]
    sample_outfile = sys.argv[6]
    snp_outfile = sys.argv[7]


    pheno = {}
    for x in open(pheno_file):
        f = x.strip().split()
        pheno[f[0]] = f[1]

    # Ignore comments
    lines = [x.split("\t") for x in open(vcf_file).readlines() if x[0:2] != '##']

    # Check format via column header line
    if lines[0][7] != "INFO" or lines[0][8] != "FORMAT":
        sys.stderr.write("VCF file is not in proper format: %s\n" % (sys.argv[1]))

    samples = lines[0][9:]
    snps = []
    genotype_matrix = []
    weights = []

    # Get list of phenotyped samples
    phenotyped_samples = tuple(set(samples) & set(pheno.keys()))

    j = 0
    for line in lines[1:]:
        j += 1
        row = []
        snps.append(line[0] + '.' + line[1])
        csq = [x for x in line[7].split(";") if x[0:4] == "CSQ="]
        flip = do_flip(line[7])
        np = 0
        if len(csq) == 0:
            weights.append(0.5)
        if len(csq) == 1:
            weights.append(isoformCsqToPolyPhenWeight(csq[0]))
        if len(csq) > 1:
            sys.stderr.write("More than one CSQ entry for SNP %s in %s\n" % (line[0] + '.' + line[1], vcf_file))
            exit(1)

        for i in range(len(samples)):
            genotype = line[i + 9]
            if True:
            # if samples[i] in pheno:
                m = re.search('(?P<allele1>[01\.])([\|\/](?P<allele2>[01\.]))?\:', genotype)
                if m:
                    g = (int(m.group('allele1')) if not flip else (1 - int(m.group('allele1'))))
                    if m.group('allele2'):
                        g +=  (int(m.group('allele2')) if not flip else (1 - int(m.group('allele2'))))
                    row.append(g)
                else:
                    print "%s: Cannot parse genotype %s at position %s" % (__file__, genotype, line[0] + '.' + line[1])
            else:
                np += 1
                # sys.stderr.write("Sample not phenotyped: %s\n" % (samples[i]))

        # print np, j, len(row), flip, sum(row), len(row)
        genotype_matrix.append(row)



    transposed_genotypes = zip(*genotype_matrix)

    if list(transposed_genotypes[0]) != [x[0] for x in genotype_matrix]:
        sys.stderr.write("Transpose of genotype matrix failed: %s\s" % (vcf_file))
        exit(1)

    of = open(sample_outfile, "w")
    print >> of, "\n".join(samples),
    of.close()

    of = open(snp_outfile, "w")
    print >> of, "\n".join(snps),
    of.close()

    of = open(geno_outfile, "w")
    for r in transposed_genotypes:
        print >> of, "\t".join([str(x) for x in r])
    of.close()

    of = open(weight_outfile, "w")
    print >> of, "\n".join([str(x) for x in weights])
    of.close()

    of = open(pheno_outfile, "w")
    for s in samples:
        if s in pheno:
            print >> of, pheno[s]
        else:
            print >> of, -9
    of.close()
