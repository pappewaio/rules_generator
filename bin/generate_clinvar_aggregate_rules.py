#!/usr/bin/env python3
"""
Post-processing script to append ClinVar aggregate companion rules.

For each rule containing `ClinVar_CLNSIG == Pathogenic`, append one additional
row where that exact predicate is replaced by
`ClinVar_submission_aggregate_clinsig == Pathogenic`.

This preserves the original row and reuses the same Disease/cID/cCond/cThresh
metadata. Existing aggregate rows are left untouched so the script is safe to
rerun on the same output file.
"""

import argparse
import csv
import os
import re


SOURCE_TOKEN = "ClinVar_CLNSIG == Pathogenic"
TARGET_TOKEN = "ClinVar_submission_aggregate_clinsig == Pathogenic"


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
    if '## ACMG Post-Processing' in content:
        return content.replace('## ACMG Post-Processing', section + '\n## ACMG Post-Processing', 1)
    if '## Rule Types Analysis' in content:
        return content.replace('## Rule Types Analysis', section + '\n## Rule Types Analysis', 1)
    return content + section


def update_summary_report(summary_path, total_rules, appended_count):
    with open(summary_path) as f:
        content = f.read()

    content = update_total_rules_summary(content, total_rules)

    section_body = (
        "*Added by `generate_clinvar_aggregate_rules.py` after base rule generation*\n\n"
        "|Category                                        |  Count|\n"
        "|:-----------------------------------------------|------:|\n"
        f"|Companion rules appended                        | {appended_count:,}|\n"
        f"|Predicate duplicated                            | `{SOURCE_TOKEN}`|\n"
        f"|Companion predicate                             | `{TARGET_TOKEN}`|\n"
        f"|**Total rules in file**                         | **{total_rules:,}**|"
    )
    content = replace_summary_section(content, "ClinVar Aggregate Post-Processing", section_body)

    with open(summary_path, 'w') as f:
        f.write(content)

    print(f"  Summary report updated: {summary_path}")


def main():
    parser = argparse.ArgumentParser(
        description='Append aggregate ClinVar companion rules for Pathogenic rows'
    )
    parser.add_argument('--rules-file', required=True, help='Input rules TSV file')
    parser.add_argument('--output-file', required=True, help='Output rules TSV file')
    parser.add_argument(
        '--summary-report',
        required=False,
        help='Path to SUMMARY_REPORT.md to update with aggregate companion stats'
    )
    args = parser.parse_args()

    print("=" * 80)
    print("Appending ClinVar aggregate companion rules")
    print("=" * 80)

    with open(args.rules_file, encoding='utf-8', newline='') as infile:
        reader = csv.DictReader(infile, delimiter='\t')
        fieldnames = reader.fieldnames
        if not fieldnames:
            raise ValueError(f"Rules file is missing a header: {args.rules_file}")

        input_rows = list(reader)

    output_rows = []
    appended_count = 0
    for row in input_rows:
        output_rows.append(row)
        rule_text = row.get('RULE', '')
        if TARGET_TOKEN in rule_text or SOURCE_TOKEN not in rule_text:
            continue

        aggregate_row = dict(row)
        aggregate_row['RULE'] = rule_text.replace(SOURCE_TOKEN, TARGET_TOKEN, 1)
        output_rows.append(aggregate_row)
        appended_count += 1

    with open(args.output_file, 'w', encoding='utf-8', newline='') as outfile:
        writer = csv.DictWriter(
            outfile,
            fieldnames=fieldnames,
            delimiter='\t',
            lineterminator='\n',
        )
        writer.writeheader()
        writer.writerows(output_rows)

    total_rules = len(output_rows)
    print(f"  Input rules: {len(input_rows):,}")
    print(f"  Companion rules appended: {appended_count:,}")
    print(f"  Total rules in output: {total_rules:,}")
    print(f"  Output file: {args.output_file}")

    if args.summary_report and os.path.exists(args.summary_report):
        update_summary_report(args.summary_report, total_rules, appended_count)

    print("=" * 80)


if __name__ == '__main__':
    main()
