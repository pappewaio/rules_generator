# Linear Architecture (from rules_generator repo)

The standalone rules_generator repo implements a linear, single-purpose function architecture.

## Core Philosophy

The problem with current production code:
- Nested if/else for checking gene counts
- Duplicate rule_combinations computation
- Mixed logic for normal vs supplemental handling
- Too many parameters passed around
- Large functions (400+ lines)

## The Solution: Linear Flow

1. Load inputs
2. Split gene strategies once (normal vs supplemental)
3. Generate rules for each strategy type
4. Combine and enhance with metadata
5. Output

Key functions:
- filter_genes_by_strategy() - Split by strategy type
- generate_normal_strategy_rules() - PTV, ClinVar, Missense rules
- generate_supplemental_strategy_rules() - HGVSc-specific rules
- combine_rule_sets() - Merge rule matrices
- add_compound_metadata() - Late binding of cID, cThresh, cCond
- add_exclusion_zones() - Terminal cutoff positions

## Character Matrix Design

All data objects (except config) are character matrices:
- Predictable behavior: No factor/numeric conversion surprises
- Consistent indexing: Always matrix[row, column] access
- No type coercion: Everything stays as strings until final output
- Easier debugging: Print matrices directly

## Function Sizing Guidelines

- Tiny (5-15 lines): Single transformations, filters, lookups
- Small (15-50 lines): Core logic functions, template applications
- Medium (50-100 lines): Complex calculations, multi-step processes
- Never Large (100+ lines): Split into smaller functions

## Benefits

1. Readability: Each function does one thing
2. Testability: Small functions easy to test in isolation
3. Maintainability: Changes to one aspect do not affect others
4. Debuggability: Linear flow easier to trace
5. Extensibility: Easy to add new rule types
6. Predictable Data Types: Character matrices eliminate bugs
7. Consistent Access Patterns: Always matrix[row, column]
