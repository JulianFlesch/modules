process ANNOTSV_ANNOTSV {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/df/df5e87ce610d595afe5f1e4017c255e53590cfa9b156c43310d637b36bfd12b3/data' :
        'community.wave.seqera.io/library/annotsv:3.4.6--c5a6da1bf4c2c8e5' }"

    // Container options are needed to allow AnnotSV to overwrite a file in a dependency directory in Singularity
    containerOptions "${ workflow.containerEngine == 'singularity' ? '--writable-tmpfs' : ''}"

    input:
    tuple val(meta), path(sv_vcf), path(sv_vcf_index), path(candidate_small_variants)
    tuple val(meta2), path(annotations)
    tuple val(meta3), path(candidate_genes)
    tuple val(meta4), path(false_positive_snv)
    tuple val(meta5), path(gene_transcripts)

    output:
    tuple val(meta), path("*.tsv")            , emit: tsv
    tuple val(meta), path("*.unannotated.tsv"), emit: unannotated_tsv, optional: true
    tuple val(meta), path("*.vcf")            , emit: vcf            , optional: true
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def cand_genes     = candidate_genes          ? "-candidateGenesFile ${candidate_genes}"              : ""
    def small_variants = candidate_small_variants ? "-candidateSnvIndelFiles ${candidate_small_variants}" : ""
    def fp_snv         = false_positive_snv       ? "-snvIndelFiles ${false_positive_snv}"                : ""
    def transcripts    = gene_transcripts         ? "-txFile ${gene_transcripts}"                         : ""

    """
    AnnotSV \\
        -annotationsDir ${annotations} \\
        ${cand_genes} \\
        ${small_variants} \\
        ${fp_snv} \\
        ${transcripts} \\
        -outputFile ${prefix}.tsv \\
        -SVinputFile ${sv_vcf} \\
        ${args}

    mv *_AnnotSV/* .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        annotsv: \$(echo \$(AnnotSV -help 2>&1 | head -n1 | sed 's/^AnnotSV //'))
    END_VERSIONS
    """

    stub:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def create_vcf = args.contains("-vcf 1") ? "touch ${prefix}.vcf" : ""

    """
    touch ${prefix}.tsv
    touch ${prefix}.unannotated.tsv
    ${create_vcf}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        annotsv: \$(echo \$(AnnotSV -help 2>&1 | head -n1 | sed 's/^AnnotSV //'))
    END_VERSIONS
    """
}
