/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { FASTP                  } from '../modules/nf-core/fastp/main'
include { BWAMEM2_MEM            } from '../modules/nf-core/bwamem2/mem/main'
include { GATK4_MARKDUPLICATES   } from '../modules/nf-core/gatk4/markduplicates/main'
include { SAMTOOLS_STATS         } from '../modules/nf-core/samtools/stats/main'
include { MOSDEPTH               } from '../modules/nf-core/mosdepth/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { FRAGMENTOMICS          } from '../subworkflows/local/fragmentomics/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_nfcore_fragmentomics_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow NFCORE_FRAGMENTOMICS {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    //
    // Reference channels (required parameters, no defaults)
    //
    def ch_fasta = channel.value([[id: 'fasta'], file(params.fasta, checkIfExists: true)])
    def ch_fai = channel.value([[id: 'genome'], file(params.fasta_fai, checkIfExists: true)])
    def ch_bwamem2_index = channel.value([[id: 'bwamem2_index'], file(params.bwamem2_index, checkIfExists: true)])
    def ch_genome_2bit = channel.value(file(params.genome_2bit, checkIfExists: true))
    def ch_gap_file = channel.value(file(params.gap_file, checkIfExists: true))

    //
    // MODULE: Run FastQC on raw reads
    //
    FASTQC(ch_samplesheet)
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.map { _meta, file -> file })

    //
    // MODULE: Adapter / quality trimming with fastp
    //
    FASTP(
        ch_samplesheet.map { meta, reads -> [meta, reads, []] },
        false, // discard_trimmed_pass
        false, // save_trimmed_fail
        false, // save_merged
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.map { _meta, file -> file })

    //
    // MODULE: Align trimmed reads with bwa-mem2 (coordinate-sorted BAM)
    //
    BWAMEM2_MEM(
        FASTP.out.reads,
        ch_bwamem2_index,
        ch_fasta,
        true, // sort_bam
    )

    //
    // MODULE: Mark duplicates (duplicates flagged, not removed)
    //
    GATK4_MARKDUPLICATES(
        BWAMEM2_MEM.out.bam,
        ch_fasta.map { _meta, fasta -> fasta },
        ch_fai.map { _meta, fai -> fai },
    )
    ch_multiqc_files = ch_multiqc_files.mix(GATK4_MARKDUPLICATES.out.metrics.map { _meta, file -> file })

    def ch_markdup_bam = GATK4_MARKDUPLICATES.out.bam.join(GATK4_MARKDUPLICATES.out.bai)

    //
    // SUBWORKFLOW: Filter BAM + fragmentomic feature matrices (finaletoolkit)
    //
    FRAGMENTOMICS(
        ch_markdup_bam,
        ch_fai,
        ch_genome_2bit,
        ch_gap_file,
    )

    //
    // QC on BOTH the mark-duplicated and the finaletoolkit-filtered BAMs.
    // Tag the meta id so outputs from the two stages don't collide.
    //
    def ch_qc_md = ch_markdup_bam.map { meta, bam, bai -> [meta + [id: "${meta.id}.markdup"], bam, bai] }
    def ch_qc_filtered = FRAGMENTOMICS.out.filtered_bam.map { meta, bam, bai -> [meta + [id: "${meta.id}.filtered"], bam, bai] }
    def ch_qc_bams = ch_qc_md.mix(ch_qc_filtered)

    //
    // MODULE: samtools stats
    //
    SAMTOOLS_STATS(
        ch_qc_bams,
        ch_fasta.map { _meta, fasta -> [[id: 'fasta'], fasta, file(params.fasta_fai)] },
    )
    ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_STATS.out.stats.map { _meta, file -> file })

    //
    // MODULE: mosdepth (whole-genome coverage, no interval BED)
    //
    MOSDEPTH(
        ch_qc_bams.map { meta, bam, bai -> [meta, bam, bai, []] },
        ch_fasta,
        [],
    )
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.summary_txt.map { _meta, file -> file })
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.global_txt.map { _meta, file -> file })

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'nfcore_fragmentomics_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'nfcore_fragmentomics'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
