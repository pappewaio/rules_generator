# Stepwise Improvements Roadmap (from optimize-rules-gen branch)

This is a copy of docs/rules_generation/stepwise-improvements.md from the optimize-rules-gen branch. It defines the parity-first optimization plan.

## Principles
- Maintain exact output parity by default; diffs must be intentional and documented
- Change one dimension at a time; verify with golden diffs at each step
- Keep dependencies minimal (base R first), add optional speedups behind flags

## 1) Parity Harness and Acceptance Criteria

### Golden Outputs
Store canonical artifacts under out_rule_generation/version_XX/ as baselines.

### Diff Scope (ESSENTIALS ONLY)
- outputs/*rules_file_from_carrier_list_nr_XX.tsv
- outputs/list_of_analyzed_genes.json
- outputs/list_of_analyzed_genes_comms_names.json
- outputs/list_of_analyzed_genes_science_pipeline_names.json

### Acceptance
- No diffs allowed by default
- Intentional diffs require:
  - a) Change report
  - b) Reason/cause
  - c) Sign-off

### Tooling
Helper script to run a generation and compare essentials to a baseline (see bin/rule_generation/tests/).

## 2) Reproducible Inputs and Manifests

### Input-manifest JSON per run with:
- Absolute and relative paths
- SHA256 checksums
- Effective configuration snapshot
- Tool version metadata (R version, package versions)

### Re-run Command
Recorded to ensure 1-click reproduction.

## 3) Vectorization Phase 1 (Base R only)

### Targets in rule_generator.R:
- Replace per-row loops with vectorized boolean masks
- Precompute joins/lookups with match, order, findInterval
- Hoist constants (e.g., thresholds) and compute once

### Guardrails:
- Feature flags to toggle vectorized path for A/B parity testing
- Golden diffs must be clean before enabling by default

## 4) Vectorization Phase 2 (Optional Accelerators)

- Add optional data.table implementations behind ENABLE_DATATABLE=false default
- Preserve identical outputs; measure speedups on large inputs

## 5) Building Blocks Abstraction

### Define primitives:
- Filters (frequency, quality, annotation)
- Combinators (AND/OR), cutoffs, per-gene overrides, position exclusions

### Migration:
- Keep current templates working
- Migrate template expansion to call primitives under the hood

### Result:
Clearer mapping from template lines to executable logic and better testability.

## 6) Metadata and Change Reporting

- Unified change taxonomy: added/removed/modified (with cause)
- Per-gene delta summaries and top drivers
- Extend version_metadata.json and SUMMARY_REPORT.md with the above

## 7) CI Gate

- Automate parity checks on PRs
- Allow baseline updates via an explicit flag and a short human summary

## 8) Standalone Summary Report Subcommand

### Implementation Status: Complete

Decoupled reporting to compare existing outputs without regenerating rules.

### Current Script
bin/rule_generation/lib/generate_summary_report_standalone.R

### Modes:
- --mode rules: rules-only comparison; writes SUMMARY_REPORT_rules.md
- --mode inputs: minimal inputs availability; writes SUMMARY_REPORT_inputs.md
- --mode full (default): legacy full report (kept for now)

### Usage:
```bash
# Generate rules as usual
./generate_rules.sh ...

# Then compare two output directories to produce a report
Rscript bin/rule_generation/lib/generate_summary_report_standalone.R \
   --generated-dir out_rule_generation/version_XX \
   --baseline-dir  out_rule_generation/version_AA \
   --summary-out   out_rule_generation_summary_report \
   --mode rules
```

### Output Location:
out_rule_generation_summary_report/<BASE>_vs_<GEN>/SUMMARY_REPORT_<mode>.md
(e.g., 46B_vs_46C/SUMMARY_REPORT_rules.md)

### Notes:
Rules-only report currently avoids parsing rule strings for type tables; we plan to add explicit rule_type/inheritance_type columns to the TSV to recreate those tables reliably.

## 9) Repo Split Readiness

- Establish a clean package boundary for rule_generation (no cross-deps on RVC internals)
- Subtree extraction plan and mirrored wrapper script in RVC during transition

## Milestones and Exit Criteria

| Milestone | Focus | Exit Criteria |
|-----------|-------|---------------|
| M1 | Parity harness + manifests | Docs complete, harness working |
| M2 | Phase 1 vectorization | Top hotspots vectorized, parity proven |
| M3 | Building blocks under templates | Parity proven, primitives defined |
| M4 | Optional accelerators | Wired but off by default |
| M5 | Enhanced reporting + metadata | Shipped without rule changes |
| M6 | Repo split | Mirrored wrapper, CI parity gate |

## Recommended Approach

Start with M1 (parity harness) regardless of other decisions. This provides:
1. Safety net for all future changes
2. Clear acceptance criteria
3. Reproducibility guarantees

Then proceed through M2-M6 incrementally, verifying parity at each step.
