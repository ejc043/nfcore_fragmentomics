//
// Fragmentomics: filter the mark-duplicated BAM to the finaletoolkit read set,
// then derive fragmentomic feature matrices (length bins, end motifs, DELFI).
//
// Tool versions are reported through the `versions` topic channel (collected in
// the main workflow), so they are not threaded explicitly here.
//

include { FILTER_BAM                   } from '../../../modules/local/filter_bam/main'
include { MAKE_INTERVALS               } from '../../../modules/local/make_intervals/main'
include { FINALETOOLKIT_FRAGLENGTHBINS } from '../../../modules/local/finaletoolkit/fraglengthbins/main'
include { FINALETOOLKIT_ENDMOTIFS      } from '../../../modules/local/finaletoolkit/endmotifs/main'
include { FINALETOOLKIT_DELFI          } from '../../../modules/local/finaletoolkit/delfi/main'

workflow FRAGMENTOMICS {

    take:
    ch_bam         // channel: [ val(meta), path(bam), path(bai) ] (mark-duplicated)
    ch_fai         // channel: [ val(meta), path(fai) ]            (genome .fai, for DELFI bins)
    ch_genome_2bit // value channel: path(genome.2bit)
    ch_gap_file    // value channel: path(gap.bed)

    main:

    //
    // Filter to the proper-pairs / MAPQ / dedup / soft-clip read set finaletoolkit uses
    //
    FILTER_BAM(ch_bam)

    def ch_filtered = FILTER_BAM.out.bam.join(FILTER_BAM.out.bai)

    //
    // DELFI bins: fixed-size windows + chrom.sizes from the genome .fai (computed once)
    //
    MAKE_INTERVALS(ch_fai)

    //
    // Fragmentomic feature matrices
    //
    FINALETOOLKIT_FRAGLENGTHBINS(ch_filtered)

    FINALETOOLKIT_ENDMOTIFS(ch_filtered, ch_genome_2bit)

    FINALETOOLKIT_DELFI(
        ch_filtered,
        MAKE_INTERVALS.out.sizes.map { _meta, sizes -> sizes }.first(),
        ch_genome_2bit,
        MAKE_INTERVALS.out.bed.map { _meta, bed -> bed }.first(),
        ch_gap_file,
    )

    emit:
    filtered_bam = ch_filtered                          // channel: [ val(meta), path(bam), path(bai) ]
    bins         = FINALETOOLKIT_FRAGLENGTHBINS.out.bed  // channel: [ val(meta), path(bed) ]
    motifs       = FINALETOOLKIT_ENDMOTIFS.out.motifs    // channel: [ val(meta), path(tsv) ]
    delfi        = FINALETOOLKIT_DELFI.out.bed           // channel: [ val(meta), path(bed) ]
}
