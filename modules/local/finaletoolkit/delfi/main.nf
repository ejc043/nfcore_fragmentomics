process FINALETOOLKIT_DELFI {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/finaletoolkit:0.11.1--pyhdfd78af_0'
        : 'quay.io/biocontainers/finaletoolkit:0.11.1--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(bam), path(bai)
    path chrom_sizes
    path genome_2bit
    path bins_bed
    path gap_file

    output:
    tuple val(meta), path("*.delfi.bed"), emit: bed
    tuple val("${task.process}"), val('finaletoolkit'), eval("finaletoolkit --version 2>&1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n1"), topic: versions, emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Positional args (in order): BAM, chrom.sizes (autosomes), genome.2bit, bins BED
    def args      = task.ext.args ?: ''
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def window    = params.delfi_window_size
    def min_frag  = params.delfi_min_frag_size
    def short_len = params.delfi_short
    def long_len  = params.delfi_long
    """
    finaletoolkit delfi \\
        --window-size ${window} \\
        -R \\
        -w ${task.cpus} \\
        -v \\
        --gap-file ${gap_file} \\
        -m ${min_frag} \\
        -sh ${short_len} \\
        -l ${long_len} \\
        -o ${prefix}.delfi.bed \\
        ${args} \\
        ${bam} \\
        ${chrom_sizes} \\
        ${genome_2bit} \\
        ${bins_bed}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.delfi.bed
    """
}
