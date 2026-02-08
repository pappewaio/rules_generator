# Moving Out: Extracting rules_generator

This folder contains documentation for extracting the rule generation code to its own repository.

## Documents

| Document | Purpose |
|----------|---------|
| [overview.md](overview.md) | Assessment of current attempts and decision points |
| [step-by-step-extraction.md](step-by-step-extraction.md) | Detailed extraction steps and file checklist |

## Decision Made

We are proceeding with **Option A: Gradual Optimization**, which means:

1. Continue using the production code in `bin/rule_generation/`
2. Apply parity-first optimizations incrementally
3. Extract to separate `rules_generator` repo when clean

## New Repo Name

The new repo will be called `rules_generator`, reusing the good name from the previous attempt but with fresh content based on the current production code.

## Quick Start for Extraction

See [step-by-step-extraction.md](step-by-step-extraction.md) for the complete guide. Summary:

1. Archive or delete old `/home/ubuntu/jesper/rules_generator/`
2. Create fresh repo with `git init`
3. Copy files from `bin/rule_generation/lib/` to `bin/R/`
4. Copy and adapt `generate_rules.sh`
5. Run parity checks
6. Create wrapper in RVC
