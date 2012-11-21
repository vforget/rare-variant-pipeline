# Rare Variant Analysis Pipeline

*Author*: Vince Forgetta

*Contact*: <vincenzo.forgetta@mail.mcgill.ca>

## Synopsis

To conduct rare variant analysis on a genome wide scale using programs such as VT, SKAT, and RR.  The pipeline uses Grid Engine to parallelize computation.

## Requirements

* R libraries:
 * VT and its dependancies: Rsge, getopt, doMC
 * SKAT and its dependencies.
* Linux
* Grid Engine with a queue named all.q
* Python, Perl, gawk
* tabix

## Install

Update the PATH variable to the tabix executable in bin/tabix.bash

Once all requirements have been satisfied, run the test suite:

    cd test
    make test

Verify that results appear in \*/\*_results.txt:

    watch cat \*/\*_results.txt

Results may take a short while to appear. Check the status of the job using qstat.

## Input Files

The following files are required by the pipeline:

* **VCF file(s):** One VCF file for each chromosome, named [0-9XY]+.*.vcf.gz, e.g., 1.beagle.impute2.anno.csq.20120427.vcf.gz. If available, PolyPhen scores are extracted and used as weights in the rare variant association tests. If not available, weight value is set to 0.5.

* **Region file:** A single file specifying the regions from which to extract SNPs from the VCF files. Format of the file contents are:

    10 100003847 100004653 C10orf28  
    10 100007442 100008748 LOXL4  
    10 100010821 100010933 LOXL4  
    10 100011322 100011459 LOXL4  
    10 100012109 100012225 LOXL4  
    10 100013309 100013553 LOXL4  
    10 100015333 100015496 LOXL4  
    10 100016536 100016704 LOXL4  

  Each line consists of 4 fields: chrom, start, end, target_name. Chrom number should match the chromosome designation used for naming the VCF files. For example, a region file may consist of exon coordinates for all human genes.
  
* **Target file:** A file containing target names, one per line. Target names are the values in column 4 of the region file that you want to process through the pipeline. Example:
    
	C10orf28  
	LOXL4  

* **Phenotype file:** A file containing phenotype values per sample. Format of the file is:

   UK10K\_124350    -2.769557  
   UK10K\_88736     -2.529971  
   QTL210350       -2.521555  
   QTL218819       -2.39639  
   QTL211631       -2.383679  
   UK10K\_TW5124812 -2.374143  
   UK10K\_137674    -2.339074  
   QTL218614       -2.235212  
   QTL190321       -2.209102  
   QTL210568       -2.16449  

  Each line consists of 2 fields: sample name, phenotype value. 

* ** Parameter file:** A file containing parameters to use for the pipeline. Format of the file is:
    
	\# SNP FILTERS  
	MAF=0.01  
    \# WINDOW PARAMETERS  
    WIN\_RUN=Y  
    WIN\_SIZE=50  
    WIN\_STEP=25  
    WIN\_MIN=20  
    \# VT PARAMETERS  
    VT\_RUN=Y  
    VT\_NPERM=1000  
    VT\_USE\_WEIGHTS=TRUE  
    \# SKAT PARAMETERS  
    SKAT\_RUN=Y  
    SKAT\_USE\_WEIGHTS=TRUE  
    SKAT\_TRAIT\_TYPE=C  
    SKAT\_RESAMP\_SIZE=1000  
    \# RR PARAMETERS  
    RR\_RUN=Y  
    RR\_USE\_WEIGHTS=TRUE  
    RR\_NPERM=1000  
    RR\_MAXPERM=1000000  
    RR\_NONSIG=250  

 A [template](https://docs.google.com/spreadsheet/ccc?key=0AgyWLMiisFxAdGNSanhvQ2gtc1g2dkFMeTR3THhDSlE) has been provided for you to easily modify these parameters. Copy paste the area indicated on the template to a text file. Specify this file as a parameter to the pipeline.

## Pipeline Overview

The pipeline consists of a series of steps. 

A flow diagram illustrating the pipeline is depicted below:

 <img src="https://raw.github.com/vforget/rare-variant-pipeline/master/doc/rv-flow.png" width=40% />

Three input files are required (in black background): a directory with VCF files, a regions file, a target list file, and a phenotype file, and a parameter file (not shown). Intermediate results are boxed and programs are within pointed boxes.

Once these input file are ready, you can proceed to execute the pipeline.

## How to Run the Pipeline

To run the pipeline execute the following command:

    run\_pipeline.bash  
	    -r regions.txt \
		-t targets.txt \
		-v ~/share/UK10K_COHORT/REL-2011-12-01/v4/ \
		-p pheno/pheno_FA_uk10k.txt \
		-x params.txt \
	
A description of all command line flags:

    -h                  Show help.
    -r    [filename]    Regions file (required).
    -t    [filename]    Target file (required).
    -v    [directory]   Source directory with genotype files in VCF format (required).
    -p    [file]        Phenotype file (required).
    -x    [file]        Parameter file (required).
    -c    [file]        Covariates file (optional).

## Results

Each rare variant association test produced one output directory i.e. <rv\_test\_name>.output (e.g. skat.output).  For example, the SKAT results directory would contain:

* skat\_results.txt: This is the **PRIMARY** results file. Depending on the association test, the columns will vary, but all should contains the target name being tested and one or more p-values from the association test.
* output/: Output file for the association tests on a per target basis.  While highly verbose, may be useful in getting more details or inspecting why certain jobs failed.
* jobs/: A directory containing jobs submitted to Grid Engine job array.
* log/: A directory containing output from the pipeline. Might be useful when inspecting why certain jobs failed
* submit\_jobs.skat5544.bash: The script used to submit the Grid Engine job array.
