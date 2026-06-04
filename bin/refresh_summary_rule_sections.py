#!/usr/bin/env python3
"""
Refresh summary report sections that depend on the final post-processed rules TSV.

The main report is initially generated before Python post-processing appends ACMG,
ClinVar aggregate, and optional devel rules. This script recalculates the rule-
dependent markdown sections from the final TSV so the report stays internally
consistent.
"""

import argparse
import csv
import re


RULE_TYPE_PATTERNS = [
    ("ClinVar P/LP (STARS >= 1)", re.compile(r"ClinVar_CLNSIG == Pathogenic.*STARS >= 1|ClinVar_CLNSIG == Likely_pathogenic.*STARS >= 1")),
    ("Frameshift/Stop Gained", re.compile(r"Consequence == frameshift_variant|Consequence == stop_gained")),
    ("Missense Variants", re.compile(r"Consequence == missense_variant")),
    ("Splice Site Variants", re.compile(r"splice_acceptor_variant|splice_donor_variant|splice_region_variant")),
    ("SpliceAI Predictions", re.compile(r"SpliceAI_pred")),
    ("Specific Variants (HGVSc)", re.compile(r"HGVSc =~")),
    ("Special/Validation Rules", re.compile(r"Validation|HFE|CFTR|HBB")),
]

INHERITANCE_KEYS = [
    ("Autosomal Recessive (cThresh=2)", "2"),
    ("Dominant/Other (cThresh=1)", "1"),
]


def load_rules(path):
    with open(path, encoding="utf-8", newline="") as infile:
        reader = csv.DictReader(infile, delimiter="\t")
        rows = list(reader)
    return rows


def analyze_rules(rows):
    rule_types = {}
    for label, pattern in RULE_TYPE_PATTERNS:
        rule_types[label] = sum(bool(pattern.search(row.get("RULE", ""))) for row in rows)

    inheritance = {}
    for label, target in INHERITANCE_KEYS:
        inheritance[label] = sum(str(row.get("cThresh", "")).strip() == target for row in rows)

    return {
        "total_rules": len(rows),
        "rule_types": rule_types,
        "inheritance": inheritance,
    }


def format_int(value):
    return f"{int(value):,}"


def format_change(value):
    value = int(value)
    if value > 0:
        return f"+{value:,}"
    if value < 0:
        return f"{value:,}"
    return "0"


def build_rule_types_section(current, previous=None):
    previous = previous or {"total_rules": 0, "rule_types": {}}
    lines = [
        "## Rule Types Analysis",
        "*Breakdown of rules by variant consequence type and classification method*",
        "",
        "|Rule Type                 | Previous| Current|  Change|",
        "|:-------------------------|--------:|-------:|-------:|",
    ]

    for label, _ in RULE_TYPE_PATTERNS:
        prev_count = previous["rule_types"].get(label, 0)
        curr_count = current["rule_types"].get(label, 0)
        lines.append(
            f"|{label:<25}|{format_int(prev_count):>9}|{format_int(curr_count):>8}|{format_change(curr_count - prev_count):>8}|"
        )

    prev_total = previous.get("total_rules", 0)
    curr_total = current["total_rules"]
    lines.append(
        f"|**Unique Rules (actual)** |{format_int(prev_total):>9}|{format_int(curr_total):>8}|{format_change(curr_total - prev_total):>8}|"
    )
    lines.extend(
        [
            "",
            "**Rule Type Changes Analysis:**",
            "- Rule type categories overlap, so the final row shows the actual unique rule count rather than the sum of category rows.",
            "",
        ]
    )
    return "\n".join(lines)


def build_inheritance_section(current, previous=None):
    previous = previous or {"total_rules": 0, "inheritance": {}}
    lines = [
        "## Inheritance Patterns",
        "*Distribution of rules by inheritance pattern determining variant counting thresholds*",
        "",
        "|Inheritance Pattern             | Previous| Current| Change|",
        "|:-------------------------------|--------:|-------:|------:|",
    ]

    for label, _ in INHERITANCE_KEYS:
        prev_count = previous["inheritance"].get(label, 0)
        curr_count = current["inheritance"].get(label, 0)
        lines.append(
            f"|{label:<31}|{format_int(prev_count):>9}|{format_int(curr_count):>8}|{format_change(curr_count - prev_count):>7}|"
        )

    prev_total = sum(previous["inheritance"].values())
    curr_total = sum(current["inheritance"].values())
    lines.append(
        f"|**TOTAL**                       |{format_int(prev_total):>9}|{format_int(curr_total):>8}|{format_change(curr_total - prev_total):>7}|"
    )
    lines.append("")
    return "\n".join(lines)


def replace_section(content, heading, replacement):
    pattern = rf"## {re.escape(heading)}\n.*?(?=\n## |\Z)"
    return re.sub(pattern, replacement.rstrip() + "\n", content, flags=re.S)


def update_total_rules_summary(content, current_total, previous_total=None):
    content = re.sub(
        r"\*\*Total Rules Generated:\*\* [\d,]+",
        f"**Total Rules Generated:** {current_total:,}",
        content,
    )

    if previous_total is None:
        return content

    change = current_total - previous_total
    replacement = (
        f"|Total Rules    | {previous_total:,}| {current_total:,}| "
        f"{'+' if change > 0 else ''}{change:,}|"
    )
    return re.sub(
        r"\|Total Rules\s+\|\s*[\d,]+\|\s*[\d,]+\|\s*[+\-\d,]+\|",
        replacement,
        content,
    )


def main():
    parser = argparse.ArgumentParser(description="Refresh rule-derived summary sections")
    parser.add_argument("--rules-file", required=True, help="Final current rules TSV")
    parser.add_argument("--summary-report", required=True, help="SUMMARY_REPORT.md to update")
    parser.add_argument("--previous-rules-file", help="Previous version rules TSV for comparison")
    args = parser.parse_args()

    current = analyze_rules(load_rules(args.rules_file))
    previous = None
    if args.previous_rules_file:
        previous = analyze_rules(load_rules(args.previous_rules_file))

    with open(args.summary_report, encoding="utf-8") as infile:
        content = infile.read()

    content = update_total_rules_summary(
        content,
        current_total=current["total_rules"],
        previous_total=None if previous is None else previous["total_rules"],
    )
    content = replace_section(content, "Rule Types Analysis", build_rule_types_section(current, previous))
    content = replace_section(content, "Inheritance Patterns", build_inheritance_section(current, previous))

    with open(args.summary_report, "w", encoding="utf-8") as outfile:
        outfile.write(content)

    print(f"Refreshed rule-derived summary sections: {args.summary_report}")


if __name__ == "__main__":
    main()
