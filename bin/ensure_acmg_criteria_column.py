#!/usr/bin/env python3
"""
Ensure the rules TSV has a consistent ACMG_criteria column.

- If the input file has 5 columns, append an empty ACMG_criteria column.
- If the input file already has 6 columns including ACMG_criteria, keep it as-is.
"""

import argparse
import csv


REQUIRED_FIELDS = ["Disease_report", "RULE", "cID", "cCond", "cThresh"]
TARGET_FIELDS = REQUIRED_FIELDS + ["ACMG_criteria"]


def main():
    parser = argparse.ArgumentParser(description="Normalize rules TSV to include ACMG_criteria column")
    parser.add_argument("--rules-file", required=True, help="Input rules TSV file")
    parser.add_argument("--output-file", required=True, help="Output rules TSV file")
    args = parser.parse_args()

    with open(args.rules_file, encoding="utf-8", newline="") as infile:
        reader = csv.DictReader(infile, delimiter="\t")
        fieldnames = reader.fieldnames
        if not fieldnames:
            raise ValueError(f"Rules file is missing a header: {args.rules_file}")

        missing = [field for field in REQUIRED_FIELDS if field not in fieldnames]
        if missing:
            raise ValueError(
                f"Rules file is missing required columns {missing}: {args.rules_file}"
            )

        rows = list(reader)

    with open(args.output_file, "w", encoding="utf-8", newline="") as outfile:
        writer = csv.DictWriter(
            outfile,
            fieldnames=TARGET_FIELDS,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            normalized = {field: row.get(field, "") for field in TARGET_FIELDS}
            writer.writerow(normalized)

    print("=" * 80)
    print("Ensuring ACMG_criteria column is present")
    print("=" * 80)
    print(f"  Input rows: {len(rows):,}")
    print(f"  Output file: {args.output_file}")
    print("=" * 80)


if __name__ == "__main__":
    main()
