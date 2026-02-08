# Standalone Repo: rules_generator

This is a clean rewrite attempt started in August 2025, now approximately 6 months old.

## Location
/home/ubuntu/jesper/rules_generator/

## Status
**Stale** - Last updated August 2025. May be missing features added to production since then.

## Key Characteristics

| Aspect | Value |
|--------|-------|
| Lines of R code | ~4,050 (vs ~7,500 in production) |
| Architecture | Linear flow with character matrices |
| Configuration | Modular .conf files |
| Testing | Comprehensive unit + e2e tests |
| Documentation | Extensive, including refactoring plan |

## Key Design Principles

### 1. Linear Flow
No nested if/else chains. Build results consecutively.

### 2. Single Purpose Functions
Each function does exactly what its name suggests.

### 3. Character Matrices
All data objects (except config) are character matrices for predictable behavior.

### 4. Late Binding
Add metadata (cID, cThresh, etc.) after rules are generated, not during.

### 5. Clear Names
Function names explain exactly what they do.

## Good Ideas to Borrow

1. **Linear flow architecture** - Clearer, easier to maintain
2. **Character matrices** - Predictable data handling
3. **Modular configuration** - Separate .conf files
4. **Function sizing guidelines** - 5-15 lines for tiny, never 100+
5. **Warning capture system** - Better than suppressWarnings()

## Caveats

1. **Stale codebase** - Missing 6 months of production changes
2. **Untested against current inputs** - May not produce compatible output
3. **Different output format** - Needs verification

## See Also

- linear-architecture.md - Detailed architecture design
- refactoring-plan.md - Original refactoring motivation
- config-system.md - Configuration approach
