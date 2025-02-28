# 16s analysis pipeline

This pilot analysis pipeline has been constructed to streamline the analysis of sequencing output following a 16S sequencing run from Macrogen. The pipeline integrates multiple tools to ensure efficient and comprehensive processing and can be executed using the `16s_pipeline.sh` script.  

First, the tool **Tracy** is used to perform basecalling and convert trace files (`.ab1` files) into FASTQ files. Next, **FastQC** is employed to assess the quality of the generated FASTQ files. Following this, **Trimmomatic** is used for trimming, with a default sliding window size of 50, a quality threshold of 18 (where terminal nucleotides are removed if the average quality of the window falls below 18), and a minimum sequence length set to 60.  

Sequences that pass quality control and trimming are subsequently analyzed using **BLASTn** against a pre-constructed 16S reference database, which can be created using the provided `build_16s_database.sh` script. Finally, the pipeline summarizes key results, including mean sequence quality, sequence length, and taxonomy information, n a TSV file.  

The pipeline can be executed with the following command:  

`16s_pipeline.sh -i <input_dir> -db <blast_db> -s <slidingwindow_size> -t <slidingwindow_treshold> -m <min_sequence_length>`  

**Parameters**:

* `-i`:  
Specifies the input directory containing the sequencing output files to analyze. This directory should include `.ab1` trace files and may also include `.txt` and `.pdf` files.    
* `-db`:  
Specifies the path to the BLAST database file used for sequence alignment and classification.  
* `-s`:  
Defines the size of the sliding window used for quality trimming. The sliding window determines the number of bases evaluated in each step of the quality assessment.    
* `-t`:  
Sets the quality score threshold for the sliding window. If the average quality within the window falls below this value, the sequence is trimmed.  
* `-m`:  
Specifies the minimum sequence length required after trimming to surive. Sequences shorter than this length are dropped.     
* `-h`:  
Displays usage information for the script.

The pipeline can be run in a dedicated Conda environment, and instructions for building this environment are provided below. The environment can also be constructed from a `.yml` file. The scripts and environment `.yml` file can be downloaded from this repository. An example of how to build the database and how to use the pipeline are shown below.  

```{bash introduction-conda-environment, eval = FALSE}
# Build a new Conda environment specifically for running the 16s analysis pipeline, including tools like BLAST, entrez-direct, FastQC, Tracy, and Trimmomatic.
conda create -n 16s_analysis_pipeline -c bioconda blast entrez-direct fastqc tracy trimmomatic

# Activate the newly created Conda environment to ensure all installed tools are accessible.
conda activate 16s_analysis_pipeline

# Install additional dependencies required for the pipeline.
# Note: These dependencies (e.g., curl, openssl, unzip) might already be installed in your base environment, but they are explicitly included here to ensure compatibility and reproducibility.
mamba install -c conda-forge curl openssl unzip 

# Download scripts from Git repository
wget -P scripts/ https://raw.githubusercontent.com/vtromp/16s_analysis_pipeline/refs/heads/main/scripts/build_16s_database.sh
wget -P scripts/ https://raw.githubusercontent.com/vtromp/16s_analysis_pipeline/refs/heads/main/scripts/16s_pipeline.sh
```
![Usage example:](https://github.com/vtromp/16s_analysis_pipeline/blob/475589eb70d223b84f082b06bc512b9efad47137/imgs/usage%20example.png) 
