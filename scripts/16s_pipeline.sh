echo ""

# Define input directory and parameters for analysis
slidingwindow_size=50
slidingwindow_treshold=18
min_sequence_length=1000

# Function to display help information
function usage() {
  echo "Usage: $0 -i INPUT_DIR -db BLAST_DB [-s SLIDINGWINDOW_SIZE] [-t SLIDINGWINDOW_THRESHOLD] [-m MIN_SEQUENCE_LENGTH]"
  echo
  echo "Required arguments:"
  echo "  -i, --input_dir           Path to the input directory containing files for analysis"
  echo "  -db, --blast_db            Path to the BLAST database for 16S RefSeq"
  echo
  echo "Optional arguments:"
  echo "  -s, --slidingwindow_size  Sliding window size for Trimmomatic (default: 50)"
  echo "  -t, --slidingwindow_threshold  Quality threshold for Trimmomatic (default: 20)"
  echo "  -m, --min_sequence_length Minimum sequence length for Trimmomatic (default: 100)"
  echo
  exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -i|--input_dir)
      input_dir="$2"; shift ;;
    -db|--blast_db)
      blast_db="$2"; shift ;;
    -s|--slidingwindow_size)
      slidingwindow_size="$2"; shift ;;
    -t|--slidingwindow_threshold)
      slidingwindow_threshold="$2"; shift ;;
    -m|--min_sequence_length)
      min_sequence_length="$2"; shift ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown parameter: $1"
      usage ;;
  esac
  shift
done

# Create directories for organizing files 
mkdir -p ${input_dir}/trace # Directory for trace files (.ab1)
mkdir -p ${input_dir}/pdf # Directory for PDF files
mkdir -p ${input_dir}/txt # Directory for text files

# Move relevant files tot their respective directories
mv ${input_dir}/*.ab1 ${input_dir}/trace/
mv ${input_dir}/*.pdf ${input_dir}/pdf/
mv ${input_dir}/*.txt ${input_dir}/txt/

# Log the start of the Tracy basecalling process
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : Running Tracy to basecall trace files in the directory in FASTQ format."

# Create a directory for FASTQ files
mkdir -p ${input_dir}/fastq

# Perform basecalling on trace files using Tracy
for file in ${input_dir}/trace/*;
  do
  # Extract the base name of the file (without the .ab1 extension)
  base_name=$(basename $file .ab1)
  # Define a temporary output file path for the intermediate FASTQ result
  output_tmp="${input_dir}/fastq/${base_name}.fastq.tmp"
  # Define the final output file path for the processed FASTQ file
  output_file="${input_dir}/fastq/${base_name}.fastq"
  # Run the Tracy basecalling tool to convert the trace file into a FASTQ file, save the result in the temporary file, and suppress output and errors.
  tracy basecall -o $output_tmp -f fastq $file > /dev/null 2>&1
  # Modify the FASTQ header in the temporary file to include the base name, and save the result in the final output file
  sed "1s/^@.*/@${base_name}/" $output_tmp > $output_file
  # Delete the temporary file after processing is complete
  rm -f $output_tmp
done

# Log the completion of basecalling and the start of FASTQC quality assessment for the generated FASTQ files
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : Basecalling complete. Running FastQC on the generated FASTQ files."

# Create a directory for FASTQC reports
mkdir -p ${input_dir}/fastqc

# Run FastQC on all FASTQ files
for file in ${input_dir}/fastq/*;
  do
  # Extract the base name of the FASTQ file (without the .fastq extension)
  base_name=$(basename $file .fastq)
  # Define the output directory for FastQC results
  output_directory="${input_dir}/fastqc/"
  # Run FastQC on the current FASTQ file, save the result in the output directory, and suppress standard output and errors
  fastqc $file -o $output_directory --quiet > /dev/null 2>&1
  #  Unzip the FastQC result ZIP file into the FastQC output directory
  unzip ${input_dir}/fastqc/${base_name}_fastqc.zip -d ${input_dir}/fastqc > /dev/null 2>&1
  # Remove the original ZIP file to save space
  rm -f ${input_dir}/fastqc/${base_name}_fastqc.zip
  # Remove the FastQC HTML summary file to clean up unnecessary files
  rm -f ${input_dir}/fastqc/${base_name}_fastqc.html
done

# Log the completion of FastQC analysis and the start of Trimmomatic trimming, specifying the parameters used for trimming
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : FastQC analysis complete. Running Trimmomatic with a sliding window of size ${slidingwindow_size} that will remove bases if their phred score is below ${slidingwindow_treshold}. Only sequneces with a length of >= ${min_sequence_length} are kept."

# Create a directory for processed files
mkdir -p ${input_dir}/processed

# Loop through all FASTQ files in the input directory
for file in ${input_dir}/fastq/*;
  do 
  # Extract the base name of the FASTQ file (without the .fastq extension)
  base_name=$(basename $file .fastq)
  # Define the output file path for the trimmed FASTQ file
  output_file="${input_dir}/processed/${base_name}.fastq"
  # Run Trimmomatic to perform quality trimming on the FASTQ file, using the sliding window parameters, quality threshold, and minimum sequence length
  trimmomatic SE $file $output_file -phred33 SLIDINGWINDOW:${slidingwindow_size}:${slidingwindow_treshold} MINLEN:${min_sequence_length}
# Redirect all output and errors to the Trimmomatic log file
done > ${input_dir}/processed/trimmomatic.log 2>&1

# Loop through all processed FASTQ files generated by Trimmomatic and convert them into FASTA format
for file in ${input_dir}/processed/*.fastq;
  do
  # Check if the FASTQ file is empty and skip to the next file if it is empty
  if [[ ! -s $file ]];
    then
    continue
  fi
  # Extract the base name of the FASTQ file (without the .fastq extension)
  base_name=$(basename $file .fastq)
  # Define the output file path for the converted FASTA file
  output_file="${input_dir}/processed/${base_name}.fasta"
  # Create the FASTA output file
  > $output_file
  # Read the FASTQ file line by line, starting with the header line 
  while read -r header;
    do
    # Read the sequence line
    read -r sequence
    # Read the '+' line (ignored in output)
    read -r plus
    # Read the quality line (ignored in output)
    read -r quality
    # Write a new header (base name of the FASTQ file) to the FASTA output file
    echo ">${base_name}" >> $output_file
    # Write the sequence to the output file
    echo "$sequence" >> $output_file
  # End reading the FASTQ file
  done < $file
done

# Remove all intermediate FASTQ files from the processed directory
rm -f ${input_dir}/processed/*.fastq

# Extract the number of surviving sequences from the Trimmomatic log
survived=$(grep "Surviving:" ${input_dir}/processed/trimmomatic.log | sed -n 's/.*Surviving: \([0-9]*\).*/\1/p' | grep -c '^1$')
# Extract the number of dropped sequences from the Trimmomatic log
dropped=$(grep "Dropped:" ${input_dir}/processed/trimmomatic.log | sed -n 's/.*Dropped: \([0-9]*\).*/\1/p' | grep -c '^1$')

# Log the completion of trimming and filtering, including the counts of surviving and dropped sequences, and indicate the start of BLASTn analysis for surviving sequences
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : Trimming & filtering complete. Total surviving: ${survived}. Total dropped: ${dropped}. Starting 16s RefSeq search with BLASTn for suriving sequences."

# Create a directory for storing BLAST results
mkdir -p ${input_dir}/blast

# Create a summary TSV file with headers for sample, accession number, and taxonomy information
echo -e "sample\taccession.number\ttaxonomy.information" > ${input_dir}/blast/summary.tsv

# Loop through all processed FASTA files in the input directory
for file in ${input_dir}/processed/*.fasta;
  do
  # Extract the base name of the FASTA file (without the .fasta extension)
  base_name=$(basename $file .fasta)
  # Define the output file for the BLAST results
  output_file="${input_dir}/blast/${base_name}.txt"
  # Run BLASTn using the input FASTA file against the specified database, output the results in tabular format (outfmt 6) with a maximum of 1 target sequence and 1 HSP per query, set an e-value threshold of 0.001 and suppress output messages
  blastn -query $file -db $blast_db -out $output_file -outfmt 6 -max_target_seqs 1 -max_hsps 1 -evalue 0.001 > /dev/null 2>&1
  # Extract the accession number from the BLAST output file (column 2 of the tabular output)
  accession_number=$(cat $output_file | cut -f2)
  # Retrieve taxonomy information for the accession number using efetch and xtract and format the taxonomy to extract the first two words (e.g., genus and species names)
  taxonomy_info=$(efetch -db nucleotide -id $accession_number -format docsum 2> /dev/null | xtract -pattern DocumentSummary -element Title | sed -E 's/^([[:alnum:]]+ [[:alnum:]]+).*/\1/')
  # Append the sample name, accession number, and taxonomy information to the summary TSV file
  echo -e "${base_name}\t${accession_number}\t${taxonomy_info}" >> ${input_dir}/blast/summary.tsv
done

# Log the completion of the BLAST search and indicate the generation of a summary report
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : BLAST search completed. Generating a summary report in '${input_dir}summary.tsv'."

# Add a header line to the final summary TSV file with columns for sample name, sequence quality, quality check (survived/dropped), sequence length, accession number, and taxonomy information
echo -e "sample\tmean.sequence.quality\tquality.check\tsequence.length\taccession.number\ttaxonomy.information" > ${input_dir}/summary.tsv

# Loop through each trace file in the input directory
for file in ${input_dir}/trace/*;
  do
  # Extract the base name of the trace file (without the .ab1 extension)
  base_name=$(basename $file .ab1)
  # Retrieve the mean sequence quality from the FastQC report of the corresponding FASTQ file
  mean_sequence_quality=$(cat ${input_dir}/fastqc/${base_name}_fastqc/fastqc_data.txt | grep "^>>Per sequence quality scores" -A 2 | grep -v "^>>\|^#" | cut -f 1)
  # Check if the processed FASTA file exists for this sample, if it exists, mark the quality check as "survived", otherwise, mark it as "dropped"
  if [[ -e "${input_dir}/processed/${base_name}.fasta" ]]; then
    quality_check="survived"
  else
    quality_check="dropped"
  fi
  # Determine the sequence length from the processed FASTA file, if the file exists, calculate the length by counting non-header characters, otherwise, set it as "NA"
  if [[ -e "${input_dir}/processed/${base_name}.fasta" ]]; then
    sequence_length=$(cat ${input_dir}/processed/${base_name}.fasta | grep -v ">" | tr -d '\n' | wc -c)
  else
    sequence_length="NA"
  fi
  # Retrieve the accession number and taxonomy information for the sample from the BLAST summary file, if the processed FASTA file doesn't exist, set both as "NA"
  if [[ -e "${input_dir}/processed/${base_name}.fasta" ]]; then
    accession_number=$(cat ${input_dir}/blast/summary.tsv | grep "${base_name}" | cut -f 2)
    taxonomy_info=$(cat ${input_dir}/blast/summary.tsv | grep "${base_name}" | cut -f 3)
  else
    accession_number="NA"
    taxonomy_info="NA"
  fi
  # Append the collected information for this sample to the final summary TSV file
  echo -e "${base_name}\t${mean_sequence_quality}\t${quality_check}\t${sequence_length}\t${accession_number}\t${taxonomy_info}" >> ${input_dir}/summary.tsv
done

# Remove the intermediate BLAST summary file, as its information has been incorporated into the final summary TSV file
rm -f ${input_dir}/blast/summary.tsv

# Log the successful completion of the analysis
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : Analysis completed successfully. Cheers!"
echo ""