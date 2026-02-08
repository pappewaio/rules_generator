# Rules Generation Cook Book

This cookbook consolidates all knowledge about the rules generation system from three different codebases. It serves as a reference for the gradual optimization and simplification effort.

## Purpose

The rules generation system creates classification rules from:
- **Master Gene List** (Excel) - genes, diseases, inheritance patterns, what variants to find
- **Variant List** (Excel) - specific variants for supplemental strategy genes
- **Configuration** - templates, thresholds, special cases

The output is a TSV rules file used by the rare variant classifier.

## Directory Structure

```
rules-generation-cook-book/
├── README.md                    # This file
├── current-production/          # bin/rule_generation/ (master branch)
│   ├── README.md                # Overview and workflow
│   ├── architecture.md          # Module structure
│   ├── configuration.md         # Config system
│   └── data-flow.md             # How data moves through the system
├── optimize-branch/             # optimize-rules-gen branch
│   ├── README.md                # Overview of optimization plan
│   ├── current-architecture.md  # Copy of architecture docs
│   └── stepwise-improvements.md # Copy of improvement roadmap
├── standalone-repo/             # Old attempt (for reference)
│   ├── README.md                # Overview of clean rewrite
│   ├── linear-architecture.md   # Linear flow design
│   ├── refactoring-plan.md      # Original refactoring plan
│   └── config-system.md         # Modular configuration
└── moving_out/                  # Extraction to new rules_generator repo
    ├── README.md                # Quick start
    ├── overview.md              # Assessment and decision points
    └── step-by-step-extraction.md  # Detailed extraction guide
```

## The Three Codebases

### 1. Current Production (`current-production/`)
**Location**: `bin/rule_generation/` on master branch  
**Status**: Active, in production  
**Lines of R code**: ~7,500

The battle-tested system currently in use. Full-featured but complex, with room for simplification.

### 2. Optimization Branch (`optimize-branch/`)
**Location**: `optimize-rules-gen` branch  
**Status**: Planning stage (1 commit ahead of master)

Documents the current architecture and defines a parity-first optimization roadmap. Key principle: change one dimension at a time, verify with golden diffs.

### 3. Standalone Repo (`standalone-repo/`)
**Location**: `/home/ubuntu/jesper/rules_generator/` (old attempt)  
**Status**: Stale (~6 months old)  
**Lines of R code**: ~4,050

A clean rewrite attempt with linear architecture and character matrices. Good ideas to borrow but will be replaced with fresh extraction.

## Extraction Plan (`moving_out/`)

The rule generation code will be extracted to a new `rules_generator` repo:
- See `moving_out/step-by-step-extraction.md` for the detailed guide
- The new repo reuses the good name but has fresh content from current production

## Key Concepts

### Rule Generation Workflow
1. **Load Configuration** - settings, column mappings, templates
2. **Load Input Data** - Excel files normalized to standard columns
3. **Filter Incomplete Entries** - remove rows missing essential data
4. **Split by Strategy** - "normal" vs "supplemental" gene strategies
5. **Generate Rules** - apply templates, create rule conditions
6. **Add Metadata** - compound het IDs, exclusion zones
7. **Output** - TSV rules file, JSON gene lists, summary report

### Strategy Types
- **Normal strategies**: PTV only, ClinVar P/LP, Missense and nonsense
- **Supplemental strategy**: Look up specific variants from variant list

### Key Data Structures
- **Gene List**: Disease, Gene, Inheritance, Variants.To.Find, Terminal cutoffs
- **Variant List**: Gene, Variant (HGVSc), Disease, Position
- **Rules**: Condition expressions with categories and compound metadata

## Optimization Approach (Decision Made)

We are proceeding with **Option A: Gradual Optimization** as outlined in the optimize-rules-gen branch.

Key principles:
1. **Parity-first** - maintain exact output with current production
2. **One change at a time** - verify with diffs at each step
3. **Document as we go** - this cookbook grows with our understanding
4. **Borrow good ideas** - from standalone repo architecture

## How to Use This Cookbook

1. **Understanding current behavior**: Start with `current-production/`
2. **Planning improvements**: Check `optimize-branch/stepwise-improvements.md`
3. **Architecture inspiration**: See `standalone-repo/linear-architecture.md`
4. **Extracting to new repo**: Follow `moving_out/step-by-step-extraction.md`
5. **Making changes**: Follow the parity-first approach

## Quick Reference

| What | Where |
|------|-------|
| Current production entry point | `generate_rules.sh` (project root) |
| Main R orchestrator | `bin/rule_generation/lib/generate_rules_simplified.R` |
| Core rule logic | `bin/rule_generation/lib/rule_generator.R` |
| Configuration | `bin/rule_generation/config/` (deprecated, use input-specific) |
| Column mappings | Defined in `config_reader.R` |
| Optimization roadmap | `optimize-branch/stepwise-improvements.md` |
| Clean architecture example | `standalone-repo/linear-architecture.md` |
| Extraction guide | `moving_out/step-by-step-extraction.md` |

---

*Created: 2026-02-03*  
*Purpose: Central knowledge base for rules generation optimization*
