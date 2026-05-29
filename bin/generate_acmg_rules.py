#!/usr/bin/env python3
"""
Post-processing script to append ACMG rules from per-symbol config files.

Each config row provides the disease name and full rule text to append.
The script inherits cID, cCond, and cThresh from the existing production
rules for the matching disease + gene pair, mirroring how supplemental
variant-specific rules reuse the main rule metadata.
"""

import argparse
import csv
import os
import re
from collections import Counter


GENE_PATTERN = re.compile(r'(?:^|&&\s*)(?:SYMBOL|SpliceAI_pred_SYMBOL)\s*==\s*([A-Za-z0-9_]+)')


def read_non_comment_lines(path):
    with open(path) as f:
        return [line for line in f if line.strip() and not line.lstrip().startswith('#')]


def load_existing_rules(rules_path):
    with open(rules_path, encoding='utf-8', newline='') as f:
        reader = csv.DictReader(f, delimiter='\t')
        fieldnames = reader.fieldnames
        if not fieldnames:
            raise ValueError(f"Rules file is empty: {rules_path}")
        rows = list(reader)
    if not rows and not fieldnames:
        raise ValueError(f"Rules file is empty: {rules_path}")
    for required in ['Disease_report', 'RULE', 'cID', 'cCond', 'cThresh']:
        if required not in fieldnames:
            raise ValueError(f"Rules file missing required column {required}: {rules_path}")

    target_fields = ['Disease_report', 'RULE', 'cID', 'cCond', 'cThresh', 'ACMG_criteria']
    normalized_rows = []
    for row in rows:
        normalized_rows.append({field: row.get(field, '') for field in target_fields})
    return target_fields, normalized_rows


def choose_primary_metadata(metadata_counts):
    """Choose the primary cID metadata for a disease-gene pair."""
    if len(metadata_counts) == 1:
        return next(iter(metadata_counts))

    return min(
        metadata_counts,
        key=lambda item: (int(item[0]), -metadata_counts[item], item[1], item[2])
    )


def build_metadata_lookup(rule_lines, target_pairs):
    metadata_by_pair = {}
    for row in rule_lines:
        disease = row.get('Disease_report', '')
        rule_text = row.get('RULE', '')
        cid = row.get('cID', '')
        ccond = row.get('cCond', '')
        cthresh = row.get('cThresh', '')
        if not all([disease, rule_text, cid, ccond, cthresh]):
            continue
        genes = {match.group(1).upper() for match in GENE_PATTERN.finditer(rule_text)}
        metadata = (cid, ccond, cthresh)
        for gene in genes:
            key = (disease, gene)
            if key not in target_pairs:
                continue
            metadata_by_pair.setdefault(key, Counter())[metadata] += 1

    return {
        key: choose_primary_metadata(metadata_counts)
        for key, metadata_counts in metadata_by_pair.items()
    }


def get_first_value(row, keys, default=''):
    for key in keys:
        value = row.get(key)
        if value is not None and str(value).strip():
            return str(value).strip()
    return default


def load_acmg_rules(config_dir):
    config_files = sorted(
        os.path.join(config_dir, name)
        for name in os.listdir(config_dir)
        if name.endswith('.tsv') and os.path.isfile(os.path.join(config_dir, name))
    )

    loaded_rows = []
    seen = set()
    duplicate_rows = 0
    for path in config_files:
        lines = read_non_comment_lines(path)
        if not lines:
            continue

        reader = csv.DictReader(lines, delimiter='\t')
        default_gene = os.path.splitext(os.path.basename(path))[0].upper()
        for row in reader:
            disease = get_first_value(row, ['Disease_report', 'Disease'])
            rule_text = get_first_value(row, ['RULE', 'Rule'])
            gene = get_first_value(row, ['Gene', 'SYMBOL', 'Symbol'], default_gene).upper()
            criterion = get_first_value(row, ['ACMG_criteria', 'Criterion'], 'Unspecified')

            if not disease or not rule_text:
                raise ValueError(f"Config row missing Disease/RULE in {path}")

            dedupe_key = (disease, gene, rule_text, criterion)
            if dedupe_key in seen:
                duplicate_rows += 1
                continue
            seen.add(dedupe_key)

            loaded_rows.append({
                'source_file': os.path.basename(path),
                'disease': disease,
                'gene': gene,
                'rule_text': rule_text,
                'criterion': criterion,
            })

    return config_files, loaded_rows, duplicate_rows


def update_total_rules_summary(content, total_rules):
    content = re.sub(
        r'\*\*Total Rules Generated:\*\* [\d,]+',
        f'**Total Rules Generated:** {total_rules:,}',
        content
    )
    content = re.sub(
        r'(\|Total Rules\s+\|[^|]+\|)\s*[\d,]+(\|)',
        lambda m: f'{m.group(1)} {total_rules:,}{m.group(2)}',
        content
    )

    def fix_total_rules_change(match):
        prev = int(match.group(1).strip().replace(',', ''))
        change = total_rules - prev
        sign = '+' if change > 0 else ''
        return f'|Total Rules    | {prev:>7,}| {total_rules:>6,}| {sign}{change}|'

    return re.sub(
        r'\|Total Rules\s+\|\s*([\d,]+)\|[^|]+\|[^|]+\|',
        fix_total_rules_change,
        content
    )


def replace_summary_section(content, heading, section_body):
    pattern = rf'\n## {re.escape(heading)}\n.*?(?=\n## |\Z)'
    content = re.sub(pattern, '\n', content, flags=re.S)
    section = f"\n## {heading}\n{section_body}\n"
    if '## Rule Types Analysis' in content:
        return content.replace('## Rule Types Analysis', section + '\n## Rule Types Analysis', 1)
    return content + section


def update_summary_report(summary_path, total_rules, rule_count, file_count, duplicate_rows, criterion_counts):
    with open(summary_path) as f:
        content = f.read()

    content = update_total_rules_summary(content, total_rules)

    counts_rows = [
        f"|Config files processed             | {file_count:,}|",
        f"|ACMG rules appended               | {rule_count:,}|",
        f"|Duplicate config rows skipped     | {duplicate_rows:,}|",
    ]
    for criterion, count in sorted(criterion_counts.items()):
        counts_rows.append(f"|Criterion `{criterion}`            | {count:,}|")

    section_body = (
        "*Added by `generate_acmg_rules.py` from `inputs/config/acmg/`*\n\n"
        "|Category                          |  Count|\n"
        "|:---------------------------------|------:|\n"
        + "\n".join(counts_rows)
        + f"\n|**Total rules in file**           | **{total_rules:,}**|"
    )
    content = replace_summary_section(content, "ACMG Post-Processing", section_body)

    with open(summary_path, 'w') as f:
        f.write(content)

    print(f"  Summary report updated: {summary_path}")


def main():
    parser = argparse.ArgumentParser(description='Append ACMG rules from config/acmg/')
    parser.add_argument('--rules-file', required=True, help='Input rules TSV file')
    parser.add_argument('--acmg-config-dir', required=True, help='Path to config/acmg/ directory')
    parser.add_argument('--output-file', required=True, help='Output rules TSV file')
    parser.add_argument('--summary-report', required=False, help='Path to SUMMARY_REPORT.md to update with ACMG stats')
    args = parser.parse_args()

    print("=" * 80)
    print("Appending ACMG rules from config/acmg")
    print("=" * 80)

    config_files, acmg_rows, duplicate_rows = load_acmg_rules(args.acmg_config_dir)

    if not config_files or not acmg_rows:
        print("  No ACMG config rows found; skipping")
        print("=" * 80)
        return

    fieldnames, existing_rule_rows = load_existing_rules(args.rules_file)
    target_pairs = {(row['disease'], row['gene']) for row in acmg_rows}
    metadata_lookup = build_metadata_lookup(existing_rule_rows, target_pairs)

    appended_rules = []
    criterion_counts = Counter()
    source_counts = Counter()

    for row in acmg_rows:
        lookup_key = (row['disease'], row['gene'])
        if lookup_key not in metadata_lookup:
            raise ValueError(
                f"No existing cID mapping found for disease-gene pair {row['disease']} / {row['gene']}"
            )

        cid, ccond, cthresh = metadata_lookup[lookup_key]
        appended_rules.append({
            'Disease_report': row['disease'],
            'RULE': row['rule_text'],
            'cID': cid,
            'cCond': ccond,
            'cThresh': cthresh,
            'ACMG_criteria': row['criterion'],
        })
        criterion_counts[row['criterion']] += 1
        source_counts[row['source_file']] += 1

    total = len(existing_rule_rows) + len(appended_rules)
    with open(args.output_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(
            f,
            fieldnames=fieldnames,
            delimiter='\t',
            lineterminator='\n',
        )
        writer.writeheader()
        for row in existing_rule_rows:
            writer.writerow(row)
        for row in appended_rules:
            writer.writerow(row)

    print(f"  Input production rules: {len(existing_rule_rows)}")
    print(f"  ACMG config files: {len(config_files)}")
    for source_file, count in sorted(source_counts.items()):
        print(f"    - {source_file}: {count} rules")
    if duplicate_rows:
        print(f"  Duplicate config rows skipped: {duplicate_rows}")
    print(f"  ACMG rules appended: {len(appended_rules)}")
    print(f"  Total rules in output: {total}")
    print(f"  Output file: {args.output_file}")

    if args.summary_report and os.path.exists(args.summary_report):
        update_summary_report(
            args.summary_report,
            total_rules=total,
            rule_count=len(appended_rules),
            file_count=len(config_files),
            duplicate_rows=duplicate_rows,
            criterion_counts=criterion_counts,
        )

    print("=" * 80)


if __name__ == '__main__':
    main()
