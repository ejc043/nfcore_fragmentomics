process FINALETOOLKIT_ENDMOTIFS {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/finaletoolkit:0.11.1--pyhdfd78af_0'
        : 'quay.io/biocontainers/finaletoolkit:0.11.1--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(bam), path(bai)
    path genome_2bit

    output:
    tuple val(meta), path("*.tsv"), emit: motifs
    tuple val("${task.process}"), val('finaletoolkit'), eval("finaletoolkit --version 2>&1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n1"), topic: versions, emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    finaletoolkit end-motifs \\
        -o ${prefix}.tsv \\
        -w ${task.cpus} \\
        ${args} \\
        ${bam} \\
        ${genome_2bit}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    """
}
