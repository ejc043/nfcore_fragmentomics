process MAKE_INTERVALS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/bedtools:2.31.1--hf5e1c6e_2'
        : 'quay.io/biocontainers/bedtools:2.31.1--hf5e1c6e_2'}"

    input:
    tuple val(meta), path(fai)

    output:
    tuple val(meta), path("*.genome"), emit: sizes
    tuple val(meta), path("*.bed")   , emit: bed
    tuple val("${task.process}"), val('bedtools'), eval("bedtools --version | sed 's/bedtools //'"), topic: versions, emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Build fixed-size genomic windows (DELFI bins) from a .fai index, plus the
    // chrom.sizes ("genome") file DELFI needs as its autosomes argument.
    def prefix = task.ext.prefix ?: "${meta.id}"
    def window = params.intervals_window_size
    """
    cut -f1,2 ${fai} > ${prefix}.genome
    bedtools makewindows -g ${prefix}.genome -w ${window} > ${prefix}_${window}.bed
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def window = params.intervals_window_size
    """
    touch ${prefix}.genome
    touch ${prefix}_${window}.bed
    """
}
