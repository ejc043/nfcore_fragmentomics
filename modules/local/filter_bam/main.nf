process FILTER_BAM {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c5d2818c8b9f58e1fba77ce219fdaf32087ae53e857c4a496402978af26e78c/data'
        : 'community.wave.seqera.io/library/htslib_samtools:1.23.1--5b6bb4ede7e612e5'}"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.filtered.bam")    , emit: bam
    tuple val(meta), path("*.filtered.bam.bai"), emit: bai
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), topic: versions, emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Prefilter a BAM to the exact read set finaletoolkit counts, and drop reads
    // that are too heavily soft-clipped (by proportion of the read), in a single pass.
    //   -f 3      keep paired (0x1) + properly paired (0x2)
    //   -F 3852   drop unmapped/mate-unmapped/secondary/qcfail/DUPLICATE/supplementary
    //   -G 48     drop pairs with both mates reverse (matches finaletoolkit)
    //   -q        minimum MAPQ
    //   -e        soft-clip fraction filter (sclen/qlen below max %)
    def args      = task.ext.args ?: ''
    def prefix    = task.ext.prefix ?: "${meta.id}.filtered"
    def min_mapq  = params.filter_min_mapq
    def max_sclip = params.filter_max_softclip_pct
    """
    samtools view \\
        -@ ${task.cpus} \\
        -b \\
        -f 3 \\
        -F 3852 \\
        -G 48 \\
        -q ${min_mapq} \\
        -e "sclen * 100 < qlen * ${max_sclip}" \\
        ${args} \\
        -o ${prefix}.bam \\
        ${bam}

    samtools index ${prefix}.bam
    samtools quickcheck ${prefix}.bam
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.filtered"
    """
    touch ${prefix}.bam
    touch ${prefix}.bam.bai
    """
}
