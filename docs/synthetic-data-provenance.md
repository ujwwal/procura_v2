# Synthetic data provenance

This note records the purpose of the four former Procura batch generators. The generators were removed during repository cleanup on 10 October 2026 because application startup and the current n8n evaluations do not use them.

## What the generators did

They created local SQL files, CSV answer keys, and a shared planning file for a fictional procurement dataset. They generated files rather than connecting to a database or executing the SQL themselves.

| Former generator | Records covered |
| --- | --- |
| procura_batch1_gen.py | Suppliers, catalog items, contracts, and procurement policies |
| procura_batch2_gen.py | Requisitions, requisition lines, and approval records |
| procura_batch3_gen.py | Purchase orders, purchase order lines, and goods receipts |
| procura_batch4_gen.py | Invoices, invoice lines, and invoice holds |

Later batches read earlier generated files to build linked records. The dataset included clean examples and deliberately problematic examples, such as duplicate supplier entries, inconsistent categories, missing receipts, quantity or price discrepancies, and instruction-like text inside records.

The answer keys described the intended scenarios. They were synthetic expectations, not evidence of real supplier behavior, client policy, or measured AI performance.

## What remains in the repository

The base setup uses the maintained SQL files in the db directory:

- [Base schema](../db/schema.sql) and [base seed data](../db/seed.sql).
- [Workflow schema](../db/workflows.sql) and [workflow seed data](../db/workflow-seed.sql).

Current feature evaluations use separate fixture SQL and answer keys:

| Feature | Fixture SQL | Answer key |
| --- | --- | --- |
| Invoice exceptions | [Invoice fixtures](../db/invoice-exceptions-itest.sql) | [Invoice answers](../db/invoice-exceptions-itest-answers.csv) |
| Approval review | [Approval fixtures](../db/approval-review-atest.sql) | [Approval answers](../db/approval-review-atest-answers.csv) |
| Quote extraction | [Quote fixtures](../db/quote-extraction-qtest.sql) | [Quote answers](../db/quote-extraction-qtest-answers.csv) |

These maintained files are separate from the removed batch generators. The base setup does not automatically load every evaluation fixture or recreate the entire earlier batch dataset.

## Preservation limits

Removing the generators does not remove records already stored in the database. This cleanup performs no database operations.

This note preserves the dataset's purpose, structure, and provenance. It is not a row-by-row backup and does not reproduce the exact former batches. Exact database recovery requires a separate database backup.

## Public documentation scope

This note contains only project filenames, generic record types, and dataset descriptions. It intentionally omits account details, credentials, connection strings, database host identifiers, machine-specific paths, and individual record contents.
