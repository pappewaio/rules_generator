#!/usr/bin/env python3
"""
Post-processing script to add devel_ prefixed rules with lower QC thresholds.

Takes a finished rules TSV file and produces a new file containing:
1. All original production rules (unchanged)
2. devel_ prefixed duplicates with lower QC thresholds
3. devel_ prefixed rules for devel-only genes

Usage:
    python3 generate_devel_rules.py \
        --rules-file <path_to_rules.tsv> \
        --devel-config <path_to_devel_settings.conf> \
        --devel-genes <path_to_devel_only_genes.tsv> \
        --rules-templates-dir <path_to_config/rules/> \
        --output-file <path_to_output.tsv>
"""

import argparse
import csv
import os
import re
import sys
from collections import OrderedDict


def load_devel_settings(config_path):
    settings = {}
    with open(config_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            key, value = line.split('=', 1)
            settings[key.strip()] = value.strip()
    return settings


def load_devel_genes(genes_path):
    genes = []
    with open(genes_path, newline='') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            genes.append(row)
    return genes


def load_rule_templates(templates_dir):
    templates = {}
    for fname in ['frequency_rules.txt', 'non_splice_pos_rules.txt',
                   'non_splice_rules.txt', 'spliceai_rules.txt',
                   'clinvar_rules.txt']:
        filepath = os.path.join(templates_dir, fname)
        if os.path.exists(filepath):
            with open(filepath) as f:
                lines = []
                for line in f:
                    line = line.rstrip('\n')
                    if line.strip() and not line.strip().startswith('#'):
                        lines.append(line)
                templates[fname.replace('.txt', '')] = lines
    return templates


def substitute_qc(rule_text, prod_qual, prod_dp, prod_gq, devel_qual, devel_dp, devel_gq):
    """Replace production QC values with devel QC values in a rule string."""
    result = rule_text
    result = re.sub(
        r'QUAL >= ' + re.escape(str(prod_qual)),
        f'QUAL >= {devel_qual}',
        result
    )
    result = re.sub(
        r'format_DP >= ' + re.escape(str(prod_dp)),
        f'format_DP >= {devel_dp}',
        result
    )
    result = re.sub(
        r'format_GQ >= ' + re.escape(str(prod_gq)),
        f'format_GQ >= {devel_gq}',
        result
    )
    return result


def generate_devel_only_gene_rules(genes, templates, devel_qual, devel_dp, devel_gq, frequency_template, cid_start):
    """Generate rules for devel-only genes using rule templates."""
    rules = []
    cid = cid_start

    freq_rule = frequency_template
    freq_rule = re.sub(r'QUAL >= [\d.]+', f'QUAL >= {devel_qual}', freq_rule)
    freq_rule = re.sub(r'format_DP >= \d+', f'format_DP >= {devel_dp}', freq_rule)
    freq_rule = re.sub(r'format_GQ >= \{FORMAT_GQ_THRESHOLD\}', f'format_GQ >= {devel_gq}', freq_rule)
    freq_rule = re.sub(r'format_GQ >= \d+', f'format_GQ >= {devel_gq}', freq_rule)

    for gene_info in genes:
        gene = gene_info['Gene']
        disease = gene_info['Disease']
        cthresh = 1  # Carrier genes always use threshold 1

        gene_rule = f"SYMBOL == {gene}"
        spliceai_gene_rule = f"SpliceAI_pred_SYMBOL == {gene}"
        inheritance_rule = f"{cid}\t>=\t{cthresh}"

        # non_splice_pos_rules (frameshift/stop_gained with position)
        for template in templates.get('non_splice_pos_rules', []):
            rule = f"{disease}\t{gene_rule}{template}{freq_rule}\t{inheritance_rule}"
            rules.append(rule)

        # non_splice_rules (clinvar, missense, start_lost)
        for template in templates.get('non_splice_rules', []):
            rule = f"{disease}\t{gene_rule}{template}{freq_rule}\t{inheritance_rule}"
            rules.append(rule)

        # spliceai_rules (splice variants with SpliceAI predictions)
        for template in templates.get('spliceai_rules', []):
            rule = f"{disease}\t{spliceai_gene_rule}{template}{freq_rule}\t{inheritance_rule}"
            rules.append(rule)

        cid += 1

    return rules


def main():
    parser = argparse.ArgumentParser(description='Generate devel_ prefixed rules with lower QC thresholds')
    parser.add_argument('--rules-file', required=True, help='Input rules TSV file')
    parser.add_argument('--devel-config', required=True, help='Path to devel_settings.conf')
    parser.add_argument('--devel-genes', required=True, help='Path to devel_only_genes.tsv')
    parser.add_argument('--rules-templates-dir', required=True, help='Path to config/rules/ directory')
    parser.add_argument('--output-file', required=True, help='Output rules TSV file')
    args = parser.parse_args()

    settings = load_devel_settings(args.devel_config)
    devel_qual = settings['DEVEL_QUAL']
    devel_dp = settings['DEVEL_DP']
    devel_gq = settings['DEVEL_GQ']
    cid_offset = int(settings['DEVEL_CID_OFFSET'])

    print("=" * 80)
    print("Generating devel_ rules with lower QC thresholds")
    print("=" * 80)
    print(f"  Production QC: QUAL >= 22.4, format_DP >= 8, format_GQ >= 16")
    print(f"  Devel QC:      QUAL >= {devel_qual}, format_DP >= {devel_dp}, format_GQ >= {devel_gq}")
    print(f"  cID offset:    +{cid_offset}")

    # Read original rules
    with open(args.rules_file) as f:
        lines = f.readlines()

    header = lines[0].rstrip('\n')
    original_rules = [line.rstrip('\n') for line in lines[1:] if line.strip()]

    print(f"\n  Original rules: {len(original_rules)}")

    # Generate devel duplicates
    devel_duplicates = []
    skipped = 0
    for rule_line in original_rules:
        parts = rule_line.split('\t')
        if len(parts) < 5:
            continue

        disease, rule_text, cid_str, ccond, cthresh = parts[0], parts[1], parts[2], parts[3], parts[4]

        has_qc = 'QUAL >=' in rule_text
        if not has_qc:
            skipped += 1
            continue

        new_disease = f"devel_{disease}"
        new_rule = substitute_qc(rule_text, '22.4', '8', '16', devel_qual, devel_dp, devel_gq)
        new_cid = str(int(cid_str) + cid_offset)
        devel_duplicates.append(f"{new_disease}\t{new_rule}\t{new_cid}\t{ccond}\t{cthresh}")

    print(f"  Devel duplicates: {len(devel_duplicates)} (skipped {skipped} rules without QC filters)")

    # Generate devel-only gene rules
    devel_genes = load_devel_genes(args.devel_genes)
    templates = load_rule_templates(args.rules_templates_dir)

    freq_template = templates.get('frequency_rules', [' && gnomADe_AF < 0.01 && QUAL >= 22.4 && format_DP >= 8 && format_GQ >= 16'])[0]

    max_devel_cid = max(int(line.split('\t')[2]) for line in devel_duplicates) if devel_duplicates else cid_offset
    devel_gene_cid_start = max_devel_cid + 1

    devel_gene_rules = generate_devel_only_gene_rules(
        devel_genes, templates,
        devel_qual, devel_dp, devel_gq,
        freq_template, devel_gene_cid_start
    )

    print(f"  Devel-only gene rules: {len(devel_gene_rules)} ({len(devel_genes)} genes)")

    # Write combined output
    total = len(original_rules) + len(devel_duplicates) + len(devel_gene_rules)
    with open(args.output_file, 'w') as f:
        f.write(header + '\n')
        for rule in original_rules:
            f.write(rule + '\n')
        for rule in devel_duplicates:
            f.write(rule + '\n')
        for rule in devel_gene_rules:
            f.write(rule + '\n')

    print(f"\n  Total rules in output: {total}")
    print(f"  Output file: {args.output_file}")
    print("=" * 80)


if __name__ == '__main__':
    main()
