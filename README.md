# ejc043/nfcore_fragmentomics

## Introduction

A bioinformatics pipeline that streamlines fastq preprocessing, QC, alignment, and computation of fragmentomic features. 
## Run the pipeline
nextflow run main.nf -profile slurm,singularity \
  --input samplesheet.csv --outdir results \
  --fasta genome.fa --fasta_fai genome.fa.fai \
  --bwamem2_index /path/to/bwamem2_index_dir \
  --genome_2bit genome.2bit --gap_file gaps.GRCh38.bed

## Sample sheet 
sample,fastq_1,fastq_2
SAMPLE_PAIRED_END,/path/to/fastq/files/AEG588A1_S1_L002_R1_001.fastq.gz,/path/to/fastq/files/AEG588A1_S1_L002_R2_001.fastq.gz
SAMPLE_SINGLE_END,/path/to/fastq/files/AEG588A4_S4_L003_R1_001.fastq.gz,


> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
