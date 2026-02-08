# Optimize Branch: optimize-rules-gen

This branch (1 commit ahead of master) documents the current architecture and defines a parity-first optimization roadmap.

## Location
`optimize-rules-gen` branch in the main repository

## What's Different from Master

```
Files added:
+ docs/rules_generation/current-architecture.md   (80 lines)
+ docs/rules_generation/stepwise-improvements.md  (89 lines)
+ bin/rule_generation/lib/generate_summary_report_standalone.R (268 lines)
+ bin/rule_generation/tests/write_input_manifest.R (60 lines)
+ .gitignore updates (parity/output dirs, standalone sandbox)
```

## Key Contributions

### 1. Architecture Documentation
Documents the current system as a baseline to preserve during optimization. This is now captured in [current-architecture.md](current-architecture.md).

### 2. Stepwise Improvements Roadmap
Defines a parity-first optimization plan with milestones. This is captured in [stepwise-improvements.md](stepwise-improvements.md).

### 3. Standalone Summary Report Tool
Decouples reporting from rule generation:

```bash
Rscript bin/rule_generation/lib/generate_summary_report_standalone.R \
   --generated-dir out_rule_generation/version_XX \
   --baseline-dir  out_rule_generation/version_AA \
   --summary-out   out_rule_generation_summary_report \
   --mode rules
```

Modes:
- `--mode rules` - Rules-only comparison
- `--mode inputs` - Input file analysis only
- `--mode full` - Legacy full report

### 4. Input Manifest Helper
Creates reproducible input manifests with checksums:

```bash
Rscript bin/rule_generation/tests/write_input_manifest.R \
   --version-dir out_rule_generation/version_XX
```

## Core Philosophy

### Parity-First Approach

1. **Golden outputs** - Store canonical artifacts as baselines
2. **Diff scope** - Only essential outputs matter:
   - `outputs/*rules_file_from_carrier_list_nr_XX.tsv`
   - `outputs/list_of_analyzed_genes*.json`
3. **No diffs by default** - Changes require explicit documentation
4. **One dimension at a time** - Verify at each step

### Minimal Risk

- Change one thing at a time
- Verify with golden diffs
- Keep dependencies minimal (base R first)
- Add optional speedups behind flags

## Roadmap Summary

| Milestone | Focus |
|-----------|-------|
| M1 | Parity harness + manifests + documentation |
| M2 | Phase 1 vectorization (top hotspots) |
| M3 | Building blocks under templates |
| M4 | Optional accelerators (data.table) |
| M5 | Enhanced reporting and metadata |
| M6 | Repo split with mirrored wrapper |

## How to Use

### Check Current Branch State
```bash
git log master..optimize-rules-gen --oneline
```

### View the Documentation
```bash
git show optimize-rules-gen:docs/rules_generation/current-architecture.md
git show optimize-rules-gen:docs/rules_generation/stepwise-improvements.md
```

### Merge to Current Work
```bash
git checkout tidy-up-rvc
git merge optimize-rules-gen
```

## See Also

- [current-architecture.md](current-architecture.md) - Baseline architecture
- [stepwise-improvements.md](stepwise-improvements.md) - Optimization roadmap
