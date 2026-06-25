process FINALETOOLKIT_FRAGLENGTHBINS {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/finaletoolkit:0.11.1--pyhdfd78af_0'
        : 'quay.io/biocontainers/finaletoolkit:0.11.1--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*_frag_bins.bed"), emit: bed
    tuple val(meta), path("*.svg")          , emit: histogram
    tuple val("${task.process}"), val('finaletoolkit'), eval("finaletoolkit --version 2>&1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n1"), topic: versions, emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    finaletoolkit frag-length-bins \\
        --histogram-path ${prefix}.svg \\
        -o ${prefix}_frag_bins.bed \\
        ${args} \\
        ${bam}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_frag_bins.bed
    touch ${prefix}.svg
    """
}
