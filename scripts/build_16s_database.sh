echo ""

# Create a directory for storing the downloaded NCBI 16S RefSeq records
mkdir -p "NCBI_16s_RefSeq"

# Log the start of the process to download 16S RefSeq records from the NCBI Nucleotide database
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : Downloading 16s RefSeq records from the NCBI Nucleotide database. For more information, visit https://www.ncbi.nlm.nih.gov/refseq/targetedloci/16S_process/."

# Use `esearch` and `efetch` to query the NCBI Nucleotide database for 16S RefSeq records associated with specific BioProjects, and save the results in FASTA format to the specified output directory
esearch -db nucleotide -query "33175[BioProject] OR 33317[BioProject]" | efetch -format fasta > "NCBI_16s_RefSeq/sequences.fasta" 2> /dev/null

# Log the completion of the download and the start of building a BLAST database from the downloaded sequences
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : Download complete. Building BLAST database from 16s sequences."

# Create a BLAST database from the downloaded 16S RefSeq sequences using the `makeblastdb` command
makeblastdb -in "NCBI_16s_RefSeq/sequences.fasta" -dbtype nucl > /dev/null 2>&1

# Log the completion of the BLAST database creation and provide the path to the constructed database
tm=$(date "+%Y-%m-%d %H:%M:%S %Z")
echo -e "[ $tm ] : BLAST database has been constructed and can be found in NCBI_16S_RefSeq/sequences.fasta."

# Final message :)
echo ""
echo "Have a BLAST :)"
echo ""
