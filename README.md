# Unclaimed property search tool

Code to cross-reference contacts with the California Unclaimed Property
database. Pretty barebones; this is mostly a personal exercise in learning more
SQL.


## Context

The [California State Controller's website](https://www.sco.ca.gov/upd_msg.html)
says it better than I probably would:

> California’s Unclaimed Property Law requires banks, insurance companies,
> corporations, and certain other entities to report and submit their customers’
> property to the State Controller’s Office when there has been no activity for a
> period of time (generally three years). Common types of unclaimed property are
> bank accounts, stocks, bonds, uncashed checks, insurance benefits, wages, and
> safe deposit box contents. Property does not include Real Estate. Controller
> Betty Yee safeguards this lost or forgotten property as long as it takes to
> reunite it with the rightful owners; there is no deadline for claiming it once
> it is transferred over to the State Controller’s Office.

Or, in other words -- a lot of people have "free" money just lying around, being
held by the state, waiting to be picked up.

The State of California is nice enough to [publish][records-download] this
unclaimed property list as a (at time of writing) 17 gigabyte CSV. This project
helps me quickly cross-reference that property list with my contacts, so I can
see if know anyone that has something in their name waiting to be claimed.

I think [all states](https://www.usa.gov/unclaimed-money) have some kind of
unclaimed property system, but I'm only concerned with California for the time
being.

  [records-download]: https://www.sco.ca.gov/upd_download_property_records.html


## Usage

1. Download the UCPO database
2. Download contacts as Outlook CSV
3. Run query.sql


## Things I want to do next

1. Implement some kind of ranking to filter out the signals from the noise. Rows
   that are retrieved in both queries are probably true positives. If one
   contact has many results, they likely have a common name and have most if not
   all false positives.
2. Present results in a prettier way. I'm using `tabview` right now, but it
   would be nice to prune columns imported into SQLite to make things easier to
   digest. `.import` supports reading from stdout(?), so maybe write something
   to only present provided columns. This might also have a performance impact?
3. Add a way to ignore known false positives.


## Things I learned

### Directly importing a .csv into an SQLite database with the CLI

This is as simple as:

```
sqlite> .mode csv
sqlite> .import path-to-csv.csv table-name
```

. It properly handles large files and encoding. I didn't expect encoding to be a
problem, but `csv-to-sqlite` (which I tried previously) choked on the unclaimed
property CSV with some encoding error, so having encoding handled nicely by
SQLite was very welcome.

In the past, I loaded CSVs and other tabular data into SQLite by cobbling
together something in Python, which wasn't difficult, just tedious to do more
than once.

### `INNER JOIN`

Basic SQL. Using an `INNER JOIN` to look up my contacts in the unclaimed
property database in bulk is an improvement over my original, naive approach of
generating a bunch of queries in code a la:

```
for first_name, last_name in contact:
    run_sql('SELECT * FROM unclaimed_property WHERE first_name ...')
```

I'm hesitant to say for sure that this is a performance improvement without
actually testing it (which I probably won't do). But it probably is.

### Indexes

More basic SQL.


## Benchmarks

Still thinking about the best way to organize benchmarks between iterations.
