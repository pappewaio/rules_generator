# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Dev]

## [1.0.0] - 2026-05-29

- **Introduced ACMG post-processing as a first-class rules-generation step:** ACMG criteria are now authored from per-symbol files under `config/acmg/`, appended after the main R generation, and inherit `cID`, `cCond`, and `cThresh` from existing disease-gene production rules.
- **Decoupled ACMG handling from devel rules:** The generation flow now treats ACMG rule authoring separately from optional `devel_` rule expansion, so ACMG criteria can be shipped in production without requiring the devel layer.
- **Added downstream ACMG ops support to the generated bundle:** Step inputs can include `acmg_ops_rules.tsv`, and deployment now ships that file to the dedicated `acmg_ops_main/` S3 path alongside the normal rules artifacts.
- **Added ClinVar aggregate companion rule expansion:** The generator can append `ClinVar_submission_aggregate_clinsig == Pathogenic` companion rows for existing `ClinVar_CLNSIG == Pathogenic` rules, enabling aggregate ClinVar matching without replacing the original rules.
- **Made the final rules TSV consistently ACMG-aware:** The output rules file now always includes an `ACMG_criteria` column; base production rules keep it empty, ACMG-authored rows populate it (for example `BA1`, `BS1`, `PM1`, `PS1`), and post-processing steps preserve it.
- **Normalized generated TSV line endings to LF-only:** Python-based rules post-processing now emits `\n` line endings consistently so deployed rules files do not contain CRLF bytes that disturb downstream tooling.
