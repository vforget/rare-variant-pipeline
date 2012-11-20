# Rare Variant Analysis Pipeline

*Author*: Vince Forgetta

*Contact*: <vincenzo.forgetta@mail.mcgill.ca>

## Synopsis

To conduct rare variant analysis on a genome wide scale using programs such as VT, SKAT, and RR.  The pipeline uses Grid Engine to parallelize computation.

## Issues

<span style="color:red; font-weight:bold">This is an early version of the pipeline, and was tested on a limited data set.</span>

## TODO

* Explain how to run commands NOT using SGE.

## Requirements

* R libraries:
 * VT
 * Rsge, getopt, doMC (for VT)
 * SKAT and its dependencies.
* Linux
* Grid Engine
* Python
* Perl
* tabix

## Install

Once all requirements have been satisfied, run the test suite::

    cd test
    make all

Verify that results appear in \*/\*_results.txt::

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

* **Phenotype file:** A file containing phenotype values per sample. Format of the file is::

   UK10K_124350    -2.769557  
   UK10K_88736     -2.529971  
   QTL210350       -2.521555  
   QTL218819       -2.39639  
   QTL211631       -2.383679  
   UK10K_TW5124812 -2.374143  
   UK10K_137674    -2.339074  
   QTL218614       -2.235212  
   QTL190321       -2.209102  
   QTL210568       -2.16449  

  Each line consists of 2 fields: sample name, phenotype value. 

## Program Descriptions

Programs to run the pipeline (described below) are:

* **01\_split.py** -- splits a region file by target name (column 4).
* **02\_tvcf.bash** -- Fetch SNPs or all regions within a target from a chromosome VCF file.
* **03\_window\_tvcf.bash** -- Split VCF file into overlapping window of SNPs
* **04\_vt.bash** -- Run VT using VCF file, and phenotype file. Weights are extracted from the Polyphen score within the VCF file.
* **05\_skat.bash** -- Run SKAT using VCF file, and phenotype file. Weights are extracted from the Polyphen score within the VCF file.

The above programs rely on the following:

* **tabix.bash** -- Run tabix, extracting SNPs from a region and filtering for SNPs below a specified MAF.
* **window.bash** -- The script to split a VCF file into overlapping windows of SNPs.
* **template.bash** -- Generic template used to build pipeline steps (THIS SCRIIPT IS NOT RUN).

* **vcf2skat.py** -- Convert VCF to input for SKAT.
* **skat.r** -- The R code to perform the SKAT analysis.

* **vt.bash** -- The script to convert VCF to VT and runs VT analysis.
* **vcf2vt.py** -- Convert VCF to input for VT.
* **llext.VariantTests.R** -- The R code to perform the VT analysis.

## Pipeline Steps

The pipeline consists of a series of steps that are intended to be used separately. This enables multiple analyzes to be conducted on the same data set e.g., prepare data then run VT and SKAT steps in parallel, or prepare two data sets, and run VT on them in parallel.

A flow diagram illustrating the pipeline is depicted below:

 <img src="https://raw.github.com/vforget/rare-variant-pipeline/master/doc/rv-flow.png" width=40% />

Three input files are required (in black background): VCF files, a regions file, and a phenotype file. Intermediate or results files are boxed and programs are within pointed boxes.

Once these input file are ready, you can proceed to execute steps in the pipeline.

### STEP 1: Split Region File by Target

The pipeline's smallest unit of work is a target (e.g. gene), which consists of one or more regions (e.g. exons) with a common target name (e.g. gene name). Step 1 of the pipeline splits the region file by target name::

    mkdir targets/
    cd targets/
    01_split.py exome_ranges.txt

This will create one file for each target name (e.g. gene name). Each file is named <target_name>.txt, e.g., WNT16.txt will contain all exon coordinate for that gene.

This step of the pipeline does not used Grid Engine. For ~20,000 human genes it completes in under 1 min.

### STEP 2: Fetch SNPs By Target

This step fetches the SNPs within the set of regions for each target. Results for each target are saved to a file names <target_name>.vcf, e.g., WNT16.vcf.  To run this step execute the following command::

    02_tvcf.bash WNT16.txt targets/ tvcf/  ~/share/UK10K_COHORT/REL-2011-12-01/v4 0.01

Arguments are:
  
* WNT16.txt: A file of target names. In this case the file contains one gene name, WNT16. **Only gene name is required. EXCLUDE any file extensions from the target names in the file.**
* targets/: Path to the target files created in Step 1. 
* tvcf/: Output directory. Will be created automatically by the pipeline.
* ~/share/UK10K_COHORT/REL-2011-12-01/v4/: Directory with chromosome VCF files (for more info see INPUT FILES).
* 0.01: Maximum minor allele frequency to retain SNPs, i.e. drop SNPs above 0.01 MAF.

This step requires Grid Engine. The output directory will contain the following subdirectories:

* output/ -- The VCF files for each target specified in the target file provided as the first argument.
* log/ -- Contains log data concerning each of the programs run during this step.
* sge_log/ -- Contains log data concerning the job on Grid Engine.
* jobs/ -- Job scripts that are executed on Grid Engine.

The files in the output/ directory are used are used as input to Steps 3-6.


### STEP3: Split Target VCF into Overlapping Windows

This step further splits each target VCF file into overlapping windows of SNPs. Results of each window are saved to a file named <target_name>.<window_num>.vcf, e.g., the first window for WNT16 will be named WNT16.1.vcf. To run this step execute the following command::
    03_window_tvcf.bash WNT16.txt tvcf/output/ windows/ 20 15 10

Arguments are:

* WNT16.txt: A file of target names. In this case the file contains one gene name, WNT16. **Only gene name is required. EXCLUDE any file extensions from the target names in the file.**
* tvcf/output/: A directory containing the VCF files, one for each target listed in the target name file.
* windows/: Output directory. Will be created automatically by the pipeline.
* 20: Window size. This number of SNPs will be in each window for analysis.
* 15: Step size. The next window will step to the right of the previous window by this many SNPs (20 - 15 leaves overlap of 5).
* 10: Minimum window size. If the last for a target contains fewer that 10 SNPs it is merged with the previous window.

This step requires Grid Engine. The output directory will contain the following subdirectories:

* output/ -- The files for each window across all targets specified in the target file provided as the first argument.
* log/ -- Contains log data concerning each of the programs run during this step.
* sge_log/ -- Contains log data concerning the job on Grid Engine.
* jobs/ -- Job scripts that are executed on Grid Engine.

The files in the output/ directory are used are used as input to Steps 4-6.

### STEP 4: Run Target or Window VT Analysis

This step will convert the VCF files to a format compatible for VT and perform the rare variant analysis.  Results from VT for each target or window are saved to files named either WNT16.vtline or WNT16.1.vtline, respectively. These are then merged into one file named vt_results.txt.  To analyze all windows you will need to generate a window target list. For the WNT16 example::

    ls windows/output | perl -p -e "s/\.vcf//g;" > WNT16.windows.txt

To run VT analysis on all windows of WNT16 execute the following command::

    04_vt.bash WNT16.windows.txt windows/output/ vt.window/ pheno/pheno_FA_uk10k.txt
 
Arguments are:

* WNT16.windows.txt: A file of window names. In this case the file contains one gene name, WNT16, with one window. **Only the window name is required. EXCLUDE any file extensions from the target names in the file.**
* windows/output/: A directory containing the VCF files, one for each window listed in the window list file.
* vt.window/: Output directory. Will be created automatically by the pipeline.
* pheno/pheno_FA_uk10k.txt: Phenotype file formatted as specified in section INPUT FILES.

This step requires Grid Engine. The output directory will contain the following subdirectories:

* output/ -- A directory containing the input and output files for VT. Used to generate the summary output in vt_results.txt
* vt_results.txt: This is the primary output file. It contains VT results for each target or window analyzed.
* log/ -- Contains log data concerning each of the programs run during this step.
* sge_log/ -- Contains log data concerning the job on Grid Engine.
* jobs/ -- Job scripts that are executed on Grid Engine.

### STEP 5: Run Target or Window SKAT Analysis

This step will convert the VCF files to a format compatible for SKAT and perform the rare variant analysis.  Results from SKAT for each target or window are saved to files named either WNT16.skline or WNT16.1.skline, respectively. These are then merged into one file named skat_results.txt. To analyse all windows you will need to generate a window target list. For the WNT16 example::

    ls windows/output | perl -p -e "s/\.vcf//g;" > WNT16.windows.txt

To run SKAT analysis on all windows of WNT16 execute the following command::

    05_skat.bash WNT16.windows.txt windows/output/ skat.window/ pheno/pheno_FA_uk10k.txt TRUE C
 
Arguments are:

* WNT16.windows.txt: A file of window names. In this case the file contains one gene name, WNT16, with one window. **Only the window name is required. EXCLUDE any file extensions from the target names in the file.**
* windows/output/: A directory containing the VCF files, one for each window listed in the window list file.
* skat.window/: Output directory. Will be created automatically by the pipeline.
* pheno/pheno_FA_uk10k.txt: Phenotype file formatted as specified in section INPUT FILES.
* TRUE: Set to TRUE to use Polyphen weights in SKAT analysis. Set to FALSE to ignore these weights.
* C: Whether the phenotype is continuous (C) or discrete (D).

This step requires Grid Engine. The output directory will contain the following subdirectories:

*  output/ -- A directory containing the input and output files for SKAT. Used to generate the summary output in skat_results.txt.
* skat_results.txt: This is the primary output file. It contains SKAT results for each target or window analysed.
* log/ -- Contains log data concerning each of the programs run during this step.
* sge_log/ -- Contains log data concerning the job on Grid Engine.
* jobs/ -- Job scripts that are executed on Grid Engine.

### STEP 6: Run Target or Window RR Analysis

TBD.

## Running Analysis Without SGE

The following steps can be used to run a rare variant analysis on a per target basis:

1. Extract SNPs from VCF file using tabix:

    tabix.bash WNT16.txt ~/share/UK10K_COHORT/REL-2011-12-01/v4/ WNT16.vcf 0.01
	
2. Split extracted SNPs into windows:

    window.bash tvcf/ WINT16 10 5 5 WNT16.windows/
	
3. 
	vt.bash WNT16.windows/ WINT16.1 vt.WNT16/ pheno.txt
	vcf2skat.py WNT16.vcf pheno.txt WNT16.geno WNT16.pheno WNT16.weight
    Rscript skat.r skat.WNT16/ WNT16 TRUE > WNT16.skatout 
    grep WNT16 WNT16.skatout | perl -p -e "s/.*\"([^\"]+)\".*/\1/g;" > WNT16.skline
