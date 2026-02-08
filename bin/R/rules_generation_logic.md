## Rule Generation Logic: From Input Data to Classification Rules

*This section explains exactly how the input files analyzed in Part 1 are transformed into variant classification rules through our systematic rule generation framework.*

### 📋 Core Decision Framework

Each generated rule follows this systematic decision process:

```
FOR each gene-disease combination in Master Gene List:
  ├─ Determine inheritance pattern → Set compound threshold (cThresh)
  ├─ Check 'Variants To Find' column → Select rule generation strategy
  ├─ Apply appropriate rule templates → Create variant-specific conditions
  ├─ Add quality filters → Include frequency and depth requirements
  └─ Generate final rule → Output with Disease, RULE, cID, cCond, cThresh
```

### 🧬 Inheritance Pattern Logic

The **Inheritance** column in the Master Gene List directly determines how many variants are needed to trigger a classification:

| Inheritance Pattern | Carrier Status | cThresh | Logic |
|:-------------------|:---------------|:--------|:------|
| **AR** (Autosomal Recessive) | Non-carrier | **2** | Requires 2+ variants (compound heterozygous or homozygous) |
| **XLR** (X-Linked Recessive) | Non-carrier | **2** | Requires 2+ variants in affected individuals |
| **AD** (Autosomal Dominant) | Any | **1** | Requires 1+ variant (dominant inheritance) |
| **XLD** (X-Linked Dominant) | Any | **1** | Requires 1+ variant (dominant inheritance) |
| Any pattern | **Carrier** | **1** | Carrier genes always use threshold 1 |

**Key Insight:** This threshold system enables accurate classification of both dominant conditions (1 variant needed) and recessive conditions (2 variants needed) within the same framework.

### 🎯 Rule Generation Strategies

The **'Variants To Find'** column determines which rule generation strategy is applied:

#### **"See supplemental variant list"**
- **Purpose:** Uses specific variants from the Variant Supplemental List
- **Logic:** Looks up gene in variant list → Creates HGVSc-specific rules
- **Example:** Creates rules like: `SYMBOL == BRCA1 && HGVSc =~ c.5266dupC`
- **Generates:** Specific Variants (HGVSc) rules

#### **"PTV only"**
- **Purpose:** Protein-truncating variants (frameshift, stop-gained)
- **Logic:** Applies frameshift_variant and stop_gained consequence filters
- **Example:** Creates rules like: `SYMBOL == ATM && Consequence == frameshift_variant`
- **Generates:** Frameshift/Stop Gained rules

#### **"ClinVar P and LP"**
- **Purpose:** ClinVar Pathogenic and Likely Pathogenic variants only
- **Logic:** Applies ClinVar significance filters with STARS confidence
- **Example:** Creates rules like: `SYMBOL == BRCA2 && ClinVar_CLNSIG == Pathogenic && STARS >= 1`
- **Generates:** ClinVar P/LP (STARS ≥ 1) rules

#### **"Missense and nonsense"**
- **Purpose:** Comprehensive rule set including all variant types
- **Logic:** Applies non-splice rules + position rules + SpliceAI rules
- **Example:** Creates 20+ rules covering ClinVar, missense, splice, frameshift variants
- **Generates:** Multiple types (ClinVar, Missense, Splice, Frameshift, SpliceAI) rules

### 🧩 Rule Template System

Rules are built by combining modular templates from the configuration:

```
Base Gene Rule:     SYMBOL == [GENE_NAME]
↓
Variant Conditions: && ClinVar_CLNSIG == Pathogenic && STARS >= 1
↓ 
Quality Filters:    && gnomADe_AF < 0.01 && QUAL >= 22.4 && format_DP >= 8 && format_GQ >= 19
↓
Position Exclusions: && POS > 12345678  [if applicable]
↓
Final Rule:         Disease_name \t [Complete Rule] \t cID \t >= \t cThresh
```

### 📊 Rule Type Classification

Generated rules are automatically classified into these categories based on their content:

| Rule Type | Trigger Conditions | Purpose |
|:----------|:-------------------|:--------|
| **ClinVar P/LP (STARS ≥ 1)** | Contains `ClinVar_CLNSIG == Pathogenic` + `STARS >= 1` | High-confidence clinical evidence |
| **Frameshift/Stop Gained** | Contains `Consequence == frameshift_variant` or `stop_gained` | Protein-truncating variants |
| **Missense Variants** | Contains `Consequence == missense_variant` + prediction scores | Missense with computational evidence |
| **Splice Site Variants** | Contains splice-related consequences (donor, acceptor, region) | Splicing disruption variants |
| **SpliceAI Predictions** | Contains `SpliceAI_pred_` conditions | AI-predicted splice effects |
| **Specific Variants (HGVSc)** | Contains `HGVSc =~` or `HGVSc ==` conditions | Known pathogenic variants |
| **Special/Validation Rules** | Validation rules for training/testing | Quality control and proficiency |

### 🔍 Universal Quality Filters

**Every rule** includes these mandatory quality filters to ensure reliable variant calling:

```
&& gnomADe_AF < 0.01        # Population frequency < 1% (rare variants)
&& QUAL >= 22.4            # Variant quality score ≥ 22.4
&& format_DP >= 8          # Read depth ≥ 8x coverage
&& format_GQ >= 19         # Genotype quality ≥ 19
```

These filters eliminate common population variants and low-quality calls that could lead to false positives.

### ⚠️ Special Cases & Exclusions

The system applies several types of exclusions to handle edge cases:

#### Gene Exclusions
- **Complete exclusions:** Genes like C1QTNF5, HMCN1 are completely excluded from terminal cutoff rules
- **Position cutoffs:** Genes like RP1L1 have position-based exclusions (e.g., `&& POS >10613346`)

#### Position-Specific Exclusions
- **SETBP1:** Excludes position 44701174 on chr18 for splice acceptor variants
- **GCH1:** Excludes position 54902390 on chr14 for likely pathogenic variants

#### Special Disease Rules
- **HBB:** Sickle cell vs. Beta thalassemia require different variant sets
- **HFE:** Hemochromatosis includes only specific founder mutations
- **CFTR:** Cystic fibrosis includes specific common pathogenic variants

### 🔗 Compound Heterozygote System

Each rule is part of a compound heterozygote detection system:

- **cID (Compound ID):** Groups rules for the same gene-disease combination
- **cCond (Condition):** Always `>=` (greater than or equal)
- **cThresh (Threshold):** Number of rules that must be satisfied

**Example:** For autosomal recessive gene ATM:
- Rules 1-5 all have `cID=42, cCond=>=, cThresh=2`
- A variant is classified only if ≥2 rules are satisfied
- This correctly identifies compound heterozygotes and homozygotes

### 🌳 Decision Tree Visualization

```mermaid
graph TD
    A[Gene-Disease from Master List] --> B{Variants To Find?}
    B -->|PTV only| C[Frameshift + Stop Gained Rules]
    B -->|ClinVar P and LP| D[ClinVar Pathogenic Rules]
    B -->|See supplemental| E[Look up in Variant List]
    B -->|Missense and nonsense| F[Comprehensive Rule Set]
    
    E --> G[HGVSc-specific Rules]
    F --> H[Non-splice Rules]
    F --> I[Position Rules]
    F --> J[SpliceAI Rules]
    
    C --> K[Apply Quality Filters]
    D --> K
    G --> K
    H --> K
    I --> K
    J --> K
    
    K --> L{Check Exclusions}
    L -->|Gene Excluded| M[Skip Rule]
    L -->|Position Excluded| N[Add Position Filter]
    L -->|No Exclusions| O[Generate Final Rule]
    N --> O
    
    O --> P[Disease | RULE | cID | >= | cThresh]
```

### 🎯 Summary: From Data to Rules

This systematic approach ensures that:

1. **Every input decision has a clear outcome** - No gene-disease combination is processed arbitrarily
2. **Quality is built-in** - All rules include frequency and quality filters
3. **Inheritance patterns are respected** - Recessive vs. dominant logic is automatically applied
4. **Edge cases are handled** - Special exclusions prevent false positives
5. **Traceability is maintained** - Every rule can be traced back to its input source

The following sections analyze the actual rules generated by this process and their distribution across diseases and inheritance patterns.
