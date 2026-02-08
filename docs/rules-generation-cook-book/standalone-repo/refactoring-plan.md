# Refactoring Plan (from rules_generator repo)

This is a summary of docs/REFACTORING_PLAN.md from the standalone rules_generator repo.

## Goal

Transform rule generation into a clean, linear flow with minimal branching and single-purpose functions.

## Core Principles

1. **Linear Flow**: No nested if/else chains - build results consecutively
2. **Single Purpose Functions**: Each function does exactly what its name suggests
3. **Minimal Branching**: Only branch for fundamentally different processing
4. **Late Binding**: Add metadata after rules are generated
5. **Clear Names**: Function names explain exactly what they do
6. **Character Matrices**: All data objects should be character matrices

## Problems Identified in Production Code

### In generate_rules.R
- Nested if/else for checking gene counts
- Duplicate rule_combinations computation
- Mixed logic for normal vs supplemental handling
- Too many parameters passed around

### In rules.R
- generate_rules_unified() does too much (400+ lines)
- Strategy filtering mixed with rule generation
- Compound logic mixed with basic rule creation
- Multiple return points with identical empty data frames

## New Flow Design

### Linear Orchestration
```r
config <- load_configuration(args$config_dir, logger)
inputs <- load_input_files(...)

normal_genes <- filter_normal_strategy_genes(inputs$gene_list)
supplemental_genes <- filter_supplemental_strategy_genes(inputs$gene_list)

normal_rules <- generate_normal_strategy_rules(normal_genes, config)
supplemental_rules <- generate_supplemental_strategy_rules(supplemental_genes, config, inputs$variant_list)

all_rules <- combine_rule_sets(normal_rules, supplemental_rules)
all_rules <- add_compound_metadata(all_rules, inputs$gene_list)
all_rules <- add_exclusion_zones(all_rules, inputs$cutoff_list)

write_output_files(all_rules, ...)
```

## Implementation Strategy

### Phase 1: Refactor generate_rules.R
1. Replace nested if/else with linear function calls
2. Separate normal vs supplemental processing clearly
3. Add metadata enhancement as final steps

### Phase 2: Split rules.R into focused functions
1. Add character matrix utility functions
2. Extract expand_gene_rule_combinations()
3. Create apply_rule_templates()
4. Create add_*() functions for late-binding
5. Ensure all functions work with character matrices

### Phase 3: Test and validate
1. Ensure output matches current system exactly
2. Verify performance is maintained
3. Add unit tests for each function

## Migration Path

1. Keep existing functions as *_legacy() during transition
2. Implement new functions alongside existing ones
3. Switch generate_rules.R to use new functions
4. Remove legacy functions once validated
5. Update documentation and tests
