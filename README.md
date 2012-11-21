# Rare Variant Analysis Pipeline

*Author*: Vince Forgetta

*Contact*: <vincenzo.forgetta@mail.mcgill.ca>

## Synopsis

To conduct rare variant analysis on a genome wide scale using programs such as VT, SKAT, and RR.  The pipeline uses Grid Engine to parallelize computation.

## Requirements

* R libraries:
 * VT and its dependencies: Rsge, getopt, doMC
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

* **VCF file(s):** One VCF file for each chromosome, named [0-9XY]+.*.vcf.gz, e.g., 1.beagle.impute2.anno.csq.20120427.vcf.gz. If available, PolyPhen scores are extracted and used as weights in the rare variant association tests. If not available, weight value is set to 0.5. This directory is specified to the pipeline via the -v option.

* **Region file:** A single file specifying the regions from which to extract SNPs from the VCF files. Format of the file contents are:

    10 100003847 100004653 C10orf28  
    10 100007442 100008748 LOXL4  
    10 100010821 100010933 LOXL4  
    10 100011322 100011459 LOXL4  
    10 100012109 100012225 LOXL4  
    10 100013309 100013553 LOXL4  
    10 100015333 100015496 LOXL4  
    10 100016536 100016704 LOXL4  

  Each line consists of 4 fields: chrom, start, end, target_name. Chrom number should match the chromosome designation used for naming the VCF files. A region file may consist of exon coordinates for all human genes, where target\_name is the gene name. This file is specified to the pipeline via the -r option.
  
* **Target file:** A file containing target names, one per line. Target names are the values in column 4 of the region file that you want to process through the pipeline. Example:
    
	C10orf28  
	LOXL4  

 This file is specified to the pipeline via the -t option.

* **Phenotype file:** A file containing phenotype values per sample. Format of the file is:

	sample\_id\_1    value1  
    sample\_id\_2    value2  
    sample\_id\_3    value3  
    sample\_id\_4    value4  
    sample\_id\_5    value5  
    sample\_id\_6    value6  

  Each line consists of 2 fields: sample name, phenotype value. The file is specified to the pipeline via the -p option.

* ** Parameter file:** To avoid entering a myraid of parameters on the commandline, a file containing additional parameters is required by the pipeline. Format of the file is:
    
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

 A [template](https://docs.google.com/spreadsheet/ccc?key=0AgyWLMiisFxAdGNSanhvQ2gtc1g2dkFMeTR3THhDSlE) has been provided for you to easily modify these parameters. Copy paste the area indicated on the template to a text file e.g. params.txt. Specify this file as a parameter to the pipeline (-x option).

The following describes each of these parameters:

* MAF: Maximum minor allele frequency to retain SNPs, i.e. drop SNPs
  above 0.01 MAF.
* WIN\_RUN: Whether to split targets into overlapping windows.  
* WIN\_SIZE: Window size. This number of SNPs will be in each window for
  analysis.
* WIN\_STEP: Step size. The next window will step to the right of the previous
  window by this many SNPs.
* WIN\_MIN: Minimum window size. If the last window for a target contains fewer that
  this many SNPs it is merged with the previous window.
* VT\_RUN: Choose to run VT analysis.
* VT\_NPERM: Permutations for VT analysis
* VT\_USE\_WEIGHTS: Apply Polyphen weights in VT analysis
* SKAT\_RUN: Choose to run SKAT analysis.
* SKAT\_USE\_WEIGHTS: Apply Polyphen weights in SKAT analysis
* SKAT\_TRAIT: Phenotype is continuouis (C) or discrete (D).
* SKAT\_RESAMP\_SIZE: Resampling size for SKAT.
* RR\_RUN: Choose to run RR analysis.
* RR\_USE\_WEIGHTS: Apply Polyphen weights in RR analysis
* RR\_NPERM: Permutations for RR analysis.
* RR\_MAXPERM: Max allowable permutations for RR analysis.
* RR\_NONSIG: Non-significant test count during permutation at which to stop the permutation process.


## Pipeline Overview

The pipeline consists of a series of steps. 

A flow diagram illustrating the pipeline is depicted below:

 <img src="https://raw.github.com/vforget/rare-variant-pipeline/master/doc/rv-flow.png" width=40% />

Three input files are required (in black background): a directory with VCF files, a regions file, a target list file, and a phenotype file, and a parameter file (not shown). Intermediate results are boxed and programs are within pointed boxes.

Once these input file are ready, you can proceed to execute the pipeline (see "How to Run the Pipeline" below).

The followin described each major step in the pipeline:

### STEP 1: Split Region File by Target

The pipeline's smallest unit of work is a target (e.g. gene), which consists of one or more regions (e.g. exons) with a common target name (e.g. gene name).  This step in the pipeline splits the regoin file (-r option) into a series of smaller files based on the target name in the region file.This step of the pipeline does not used Grid Engine. For ~20,000 human genes it completes in under 1 min.

### STEP 2: Fetch SNPs By Target

This step fetches the SNPs from the VCF files (-v option) within the set of regions for each target specified in the target file (-t option). Upon completion of all RV tests, **these files are deleted** to save disk space.

### STEP3: Split Target VCF into Overlapping Windows

If the WIN\_RUN parameter be set to "Y", this step further splits each target VCF file into overlapping windows of SNPs. Results of each window are saved and new target names are created by appending the window number to the target name e.g. LOXL4.1, LOXL4.2, etc.

### STEP 4: Run Rare Variant Association Tests

This step runs the selected RV tests on all targets specified in the target file (-t option) using the phenotype specified in the phenotype file (-p option).

Each rare variant association test produced one output directory i.e. <rv\_test\_name>.output (e.g. skat.output).  For example, the SKAT results directory would contain:

* skat\_results.txt: This is the **PRIMARY** results file. Depending on the association test, the columns will vary, but all should contains the target name being tested and one or more p-values from the association test.
* output/: Output file for the association tests on a per target basis.  While highly verbose, may be useful in getting more details or inspecting why certain jobs failed.
* jobs/: A directory containing jobs submitted to Grid Engine job array.
* log/: A directory containing output from the pipeline. Might be useful when inspecting why certain jobs failed
* submit\_jobs.skat5544.bash: The script used to submit the Grid Engine job array.

## How to Run the Pipeline

To run the pipeline execute the following command:

    run\_pipeline.bash  
	    -r regions.txt \
		-t targets.txt \
		-v <path_to_VCF_files> \
		-p pheno.txt \
		-x params.txt \
	
A description of all command line flags:

    -h                  Show help.
    -r    [filename]    Regions file (required).
    -t    [filename]    Target file (required).
    -v    [directory]   Source directory with genotype files in VCF format (required).
    -p    [file]        Phenotype file (required).
    -x    [file]        Parameter file (required).
    -c    [file]        Covariates file (optional).

Example running pipeline for all exons from UK10K_COHORT dataset:

Generate a list of target names from the region file:

`cut -f 4 -d ' ' ~/share/UK10K_exomes/exomes.range.txt | sort | uniq > targets.txt`
 
Alternatively, to try 50 randomly selected genes:
 
`cut -f 4 -d ' ' ~/share/UK10K_exomes/exomes.range.txt | sort | uniq | sort -R | head -n 50 > targets.txt`

Generate phenotype file:

`cut -f 2,6 ~/share/UK10K_exomes/merged/pheno.txt | tail -n +2 > pheno.txt`
	
Copy default parameters from template to param.txt.

Run pipeline:

	run_pipeline.bash \  
	    -r ~/share/UK10K_exomes/exomes.range.txt \  
		-t targets.rand50.txt \  
		-v <path_to_UK10K_release> \  
		-p pheno.txt \  
		-x params.txt
