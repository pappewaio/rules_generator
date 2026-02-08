# Moving Out the Rule Generator: Assessment of Current Attempts

This document maps out all existing attempts to separate the rule generation code from the rare variant classifier (RVC), their key differences, and provides a basis for deciding the next steps.

---

## Overview

There are currently **3 distinct codebases** related to rule generation:

| Location | Status | Lines of R code | Key Focus |
|----------|--------|-----------------|-----------|
| `bin/rule_generation/` (master) | **Active/Production** | ~7,500 lines | Full-featured, modular, currently in use |
| `optimize-rules-gen` branch | In-progress | Same as master + docs | Parity-focused optimization roadmap |
| `/home/ubuntu/jesper/rules_generator/` | Standalone repo attempt | ~4,050 lines | Clean rewrite with linear flow |

---

## 1. Current Production: `bin/rule_generation/` (master branch)

### Structure
```
bin/rule_generation/
├── lib/                          # Core R modules (~7,500 lines total)
│   ├── generate_rules_simplified.R   # Main orchestrator (513 lines)
│   ├── rule_generator.R              # Core rule logic (1,189 lines)
│   ├── generate_summary_report.R     # Reporting (2,048 lines)
│   ├── rules_analysis_comparator.R   # Version comparison (864 lines)
│   ├── generate_rules_utils.R        # Utilities (589 lines)
│   ├── config_reader.R               # Configuration (378 lines)
│   ├── predictor.R                   # Predictive analysis (336 lines)
│   ├── prediction_validator.R        # Validation (364 lines)
│   ├── input_comparator.R            # Input diff analysis (304 lines)
│   ├── logger.R                      # Logging (193 lines)
│   ├── effective_usage_tracker.R     # Usage tracking (158 lines)
│   ├── trace_file_writer.R           # File tracing (188 lines)
│   └── variant_changes_*.R           # Variant processing (342 lines)
├── config/                       # Configuration files
├── deprecated/                   # Old scripts
└── tests/                        # Sample data
```

### Key Features
- **7-Step Workflow**: Config → Input Analysis → Prediction → Rules → Validation → Deployment → Report
- **Version Comparison**: Built-in diffing between rule versions
- **Prediction/Validation**: Predicts expected changes, validates after generation
- **Stepwise Versioning**: Supports 45A, 45B, 45C workflow for incremental changes
- **Effective Usage Tracking**: Tracks which variants actually contribute to rules
- **Comprehensive Reporting**: Detailed SUMMARY_REPORT.md generation

### Pros
- Battle-tested in production
- Full feature set
- Good reporting and traceability

### Cons
- Tightly coupled to RVC repo structure
- Large codebase (~7,500 lines)
- Some legacy patterns (row-by-row loops in places)
- rule_generator.R is complex (1,189 lines, multiple responsibilities)

---

## 2. Optimization Branch: `optimize-rules-gen`

### What's Different (1 commit ahead of master)
```
Files changed:
+ docs/rules_generation/current-architecture.md   (80 lines)
+ docs/rules_generation/stepwise-improvements.md  (89 lines)
+ bin/rule_generation/lib/generate_summary_report_standalone.R (268 lines)
+ bin/rule_generation/tests/write_input_manifest.R (60 lines)
+ .gitignore updates
```

### Key Documents Added

#### `current-architecture.md`
Documents the current system as a baseline to preserve during optimization:
- Entry points and orchestration flow
- Core modules and their responsibilities  
- Configuration and template system
- Input/output structure
- Known caveats (e.g., gene exclusions bug, legacy cID assignment)

#### `stepwise-improvements.md`
Defines a **parity-first optimization roadmap**:

1. **Parity Harness**: Golden outputs, diff-based acceptance testing
2. **Reproducible Inputs**: Manifests with checksums, tool versions
3. **Vectorization Phase 1**: Replace loops with vectorized operations (base R only)
4. **Vectorization Phase 2**: Optional data.table accelerators (off by default)
5. **Building Blocks Abstraction**: Primitives for filters, combinators, cutoffs
6. **Metadata & Change Reporting**: Unified change taxonomy
7. **CI Gate**: Automated parity checks on PRs
8. **Standalone Summary Reports**: Decouple reporting from generation
9. **Repo Split Readiness**: Clean package boundary, subtree extraction plan

#### Standalone Summary Report Tool
New script to compare existing outputs without regenerating rules:
```bash
Rscript bin/rule_generation/lib/generate_summary_report_standalone.R \
   --generated-dir out_rule_generation/version_XX \
   --baseline-dir  out_rule_generation/version_AA \
   --summary-out   out_rule_generation_summary_report \
   --mode rules
```

### Pros
- Preserves production code while planning improvements
- Documents current architecture clearly
- Defines clear milestones (M1-M6)
- Parity-first approach reduces risk

### Cons
- Still planning phase, no actual optimizations implemented yet
- Same codebase complexity as master

---

## 3. Standalone Repo: `/home/ubuntu/jesper/rules_generator/`

### History
- Created: August 2025
- Last commit: ~6 months ago
- Commits: 15+ implementing a clean rewrite

### Structure
```
rules_generator/
├── bin/
│   ├── R/                        # Core R modules (~4,050 lines)
│   │   ├── generate_rules.R          # Entry point (99 lines)
│   │   ├── config.R                  # Configuration (541 lines)
│   │   ├── rules.R                   # Linear rule generation (399 lines)
│   │   ├── input.R                   # Input handling (350 lines)
│   │   ├── utils.R                   # Utilities (365 lines)
│   │   ├── generate_summary_report.R # Reporting (2,170 lines)
│   │   ├── output.R                  # Output management (75 lines)
│   │   └── validation.R              # Validation (54 lines)
│   └── bash/                     # Shell utilities
│       ├── checker.sh
│       ├── common_utils.sh
│       ├── output_functions.sh
│       ├── overwrite.sh
│       └── path_utils.sh
├── config/
│   ├── main.conf                 # Main configuration
│   ├── settings.conf             # Settings
│   ├── column_mappings.conf      # Column mappings
│   ├── paths.conf                # Path configuration
│   └── rules_assets/             # Rule templates and special cases
├── docs/                         # Comprehensive documentation
│   ├── REFACTORING_PLAN.md       # Detailed refactoring plan
│   ├── LOGGING_AND_WARNING_SYSTEM.md
│   ├── NO_MASKING_GUARANTEES.md
│   ├── TESTING_GUIDE.md
│   └── WARNING_SYSTEM_DOCUMENTATION.md
└── tests/                        # Test suite
    ├── unit/
    ├── e2e/
    └── data/
```

### Key Architectural Differences

#### Linear Rule Generation (`rules.R`)
Based on a detailed refactoring plan, implements:
- **Character matrices** for all data (predictable, no type coercion)
- **Single-purpose functions** (each function does one thing)
- **Linear flow** (no nested if/else chains)
- **Late binding** (metadata added after rule generation)

```r
# Example flow from rules.R
filter_genes_by_strategy(gene_matrix, "normal")     # Filter
expand_gene_rule_combinations(genes, strategy_map)  # Expand
apply_rule_templates(combinations, rules)           # Apply templates
add_frequency_conditions(rules, config)             # Enhance
```

#### Modular Configuration
- Separate `.conf` files loaded via `main.conf`
- Clear separation of concerns
- Bash utilities in dedicated modules

#### Warning Capture System
Comprehensive logging that:
- Never masks errors or messages
- Captures warnings for analysis
- Supports different modes (development, production, test)

### Pros
- **45% smaller codebase** (~4,050 vs ~7,500 lines)
- **Clean architecture** with linear flow
- **Well-documented** refactoring philosophy
- **Comprehensive test suite** (unit + e2e)
- **Robust warning system**
- **Standalone** - no RVC dependencies

### Cons
- **Stale** (~6 months old, may be missing recent features)
- **Untested against current production** inputs/outputs
- **Different output format** - likely incompatible without verification
- **Missing features?** - needs audit against current production

---

## Comparison Matrix

| Aspect | master | optimize-rules-gen | rules_generator |
|--------|--------|-------------------|-----------------|
| **Status** | Production | Planning | Abandoned? |
| **R code size** | ~7,500 lines | ~7,500 lines | ~4,050 lines |
| **Architecture** | Modular but complex | Same + docs | Linear/clean |
| **Rule generation** | Complex loops | Same | Vectorized approach |
| **Configuration** | Mixed in lib/ | Same | Separated .conf files |
| **Documentation** | README only | + Architecture docs | Comprehensive |
| **Testing** | Sample data only | Same | Unit + E2E tests |
| **Parity verified** | N/A (is baseline) | Planned | Unknown |
| **Last updated** | Jan 2026 | Jan 2026 | Aug 2025 |

---

## Key Decision Points

### Option A: Continue with `optimize-rules-gen` approach
**Path**: Incremental optimization of existing code

- Follow the stepwise-improvements roadmap
- Keep production code stable
- Add parity harness first
- Vectorize incrementally with feature flags
- Extract to separate repo at M6

**Effort**: Medium-High (months of incremental work)
**Risk**: Low (parity-first approach)

### Option B: Revive `rules_generator` repo
**Path**: Audit, update, and adopt the standalone rewrite

1. Audit rules_generator against current production features
2. Identify missing features and output format differences
3. Run parity tests against current rules files
4. Update to match current functionality
5. Replace bin/rule_generation/ with import from standalone repo

**Effort**: Medium (depends on delta from current production)
**Risk**: Medium (may have hidden incompatibilities)

### Option C: Hybrid approach
**Path**: Use rules_generator architecture in current repo

1. Adopt the linear flow architecture from rules_generator
2. Port the character matrix approach to existing code
3. Keep existing features, refactor internals
4. Use optimize-rules-gen parity harness for validation
5. Extract to separate repo when clean

**Effort**: High (rewrites with parity constraints)
**Risk**: Medium (architectural changes in production code)

### Option D: Start fresh with lessons learned
**Path**: New clean-room implementation

- Use optimize-rules-gen docs as specification
- Use rules_generator patterns as architecture reference
- Build with parity harness from day one
- Run parallel with production until parity achieved

**Effort**: Very High
**Risk**: High (duplicated effort, may never reach parity)

---

## Recommended Next Steps

1. **Run parity check**: Generate rules with current production, then attempt same with rules_generator. Compare outputs.

2. **Audit feature gap**: List all features in production that may be missing from rules_generator.

3. **Decide on approach**: Based on parity check and feature gap, choose Option A, B, or C.

4. **Regardless of choice**: Implement the parity harness from optimize-rules-gen roadmap first. This is valuable for any path forward.

---

## Files to Review

| File | Purpose |
|------|---------|
| `docs/rules_generation/current-architecture.md` | Baseline architecture (optimize-rules-gen) |
| `docs/rules_generation/stepwise-improvements.md` | Optimization roadmap (optimize-rules-gen) |
| `/home/ubuntu/jesper/rules_generator/docs/REFACTORING_PLAN.md` | Clean architecture philosophy |
| `/home/ubuntu/jesper/rules_generator/bin/R/rules.R` | Linear rule generation implementation |
| `bin/rule_generation/lib/rule_generator.R` | Current production rule logic |

---

*Document created: 2026-02-03*
*Purpose: Decision support for rule generator separation*
