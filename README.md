# SQL Ticket Analysis

Analysing 29,651 IT support tickets with SQL: what the tag data can and can't tell you about where a ticket belongs and how urgent it is.

Built with SQLite and pandas. The dataset is the same one behind my [agentic ticket triage project](https://github.com/shramana-sanyal/agentic-ticket-triage); but here the question is different — *what do the tags actually predict*.

## Why this needed a database

The raw CSV stores tags as a string containing a Python list:

```
"['Account', 'Outage', 'IT']"
```

One ticket, many tags: a one-to-many relationship squashed into a single text field. We cannot group, join or count on that. So the build step parses it out with `ast.literal_eval` and writes each tag as its own row.

**Schema**

| Table | Rows | Columns |
|---|---|---|
| `tickets` | 29,651 | `ticket_id`, `department`, `priority`, `body_length` |
| `ticket_tags` | 146,390 | `ticket_id`, `tag` |

1,650 unique tags, averaging 4.9 per ticket. Indexes on `ticket_tags(ticket_id)` and `ticket_tags(tag)`.

## Findings

**Tags are weak at predicting department.**

The three most common tags are Tech Support (47.7%), IT (47.2%) and Feedback: all so broad they appear across nearly every department. They're the top-ranked tag in 7 of 10 departments, which means they carry almost no routing signal.

A handful of tags *are* sharply concentrated:

| Tag | Share in one department | Department |
|---|---|---|
| Payment | 99.3% | Billing and Payments |
| Refund | 97.3% | Billing and Payments |
| Billing | 96.7% | Billing and Payments |

Nothing else clears 65%. Even the tag "IT Support" points to Technical Support only 40% of the time.

**Tags are reasonably good at predicting urgency.**

Baseline: 38.8% of all tickets are high priority. Against that:

| Tag | High priority |
|---|---|
| Service Disruption | 68.2% |
| Urgent Issue | 66.9% |
| Crash | 59.2% |

**Departments differ enormously in urgency.** Service Outages and Maintenance runs 70.7% high priority; Human Resources runs 10.4%.

## SQL techniques used

Seven queries in `queries.sql`, each also run in the notebook with its output:

| Query | Technique |
|---|---|
| Volume and priority by department | `GROUP BY`, `CASE WHEN` for conditional aggregation |
| Most common tags | `JOIN`, `COUNT`, percentage of total |
| Top 3 tags per department | CTE + `RANK() OVER (PARTITION BY ...)` |
| Tag concentration | Correlated subquery |
| Tags signalling urgency | `HAVING` to filter on aggregates |
| Department summary | `ROW_NUMBER()`, excluding noise tags |
| Baseline priority rate | Single-value aggregate for comparison |

`RANK()` rather than `ROW_NUMBER()` in the top-3 query is deliberate. This is because General Inquiry has a genuine tie at rank 2, and `ROW_NUMBER()` would have silently picked one and dropped the other.

## Files

- `sql_analysis.ipynb` — the entire analysis, from building the database from the CSV to the queries and findings
- `queries.sql` — the queries on their own, commented

## Running it

```
pip install pandas
```

Download the dataset from [Kaggle](https://www.kaggle.com/datasets/parthpatil256/it-support-ticket-data), put the CSV in the project folder, then open `sql_analysis.ipynb` and run the cells top to bottom. The first section creates `tickets.db`. Everything after it queries that database.

## Limitations

- Two tables is a thin schema. Real ticketing systems have users, assignees, SLAs and status history; this dataset has none of them.
- The tag vocabulary is uncontrolled — 1,650 tags for 10 departments, with overlapping and near-duplicate labels.
- Findings are descriptive, not causal. A tag correlating with high priority doesn't mean the tag caused the classification.
- No time dimension in the dataset, so no trend analysis.