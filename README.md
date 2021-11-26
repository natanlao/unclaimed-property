# Unclaimed property search tool

Query to cross-reference contacts with the California Unclaimed Property
database. Pretty barebones; this is a personal exercise in performance tuning
and learning more SQL.


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

You'll need:
* A copy of the unclaimed property record database saved as
  `unclaimed_property.csv`.
* A CSV of your contacts in Outlook format saved as `contacts.csv`. (Check
  unclaimed.sql for the expected format)
* sqlite3
* xsv

### Downloading the property database

```
curl 'https://dpupd.sco.ca.gov/00_All_Records.zip' > tmp.zip && unzip tmp.zip && rm tmp.zip
```

### Actually running the thing

```
sqlite3 unclaimed.db < unclaimed.sql
```

Alternatively, if you have enough RAM (about half of the size of the CSV), you
can try building the SQLite database entirely in memory:

```
sqlite3 < unclaimed.sql
```


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
4. Trim data loaded into SQLite so that the entire database can live in memory.


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

More basic SQL. Some notes:

* Sometimes you need to run `ANALYZE` to get SQLite to pick up on indexes.
* You can have multi-column ("covered") indexes.
* It's better to load your data first, then create an index. Be mindful of this,
  especially because indexes can make INSERT and UPDATE expensive.
* Binary trees!


## Benchmarks

Played around with some recommended performance tuning approaches I found online
(and some guesses). Most variations were micro-optimizations that generally
didn't change runtime substantially. I left the ones I liked in place.

In retrospect, it probably would have been a good idea to show the code for each
variation. I'll do that going forward.


### Initial commit

```
real	173m40.322s
user	155m52.334s
sys	16m43.607s
```

### With ifnull

Veridct: keep. Negligible performance improvement, but I'm lazy.

```
Executed in  170.54 mins    fish           external
   usr time  153.62 mins  375.00 micros  153.62 mins
   sys time   16.35 mins    0.00 micros   16.35 mins
```

### With an explicit `SELECT ...` instead of `SELECT *`

Veridct: keep. Negligible performance improvement, but the output is easier to
read.

```
Executed in  169.88 mins    fish           external
   usr time  152.56 mins  184.00 micros  152.56 mins
   sys time   16.59 mins   40.00 micros   16.59 mins
```

### With `WHERE` conditions moved to `ON`

Veridct: keep. Outperforms the previous two approaches, though I still need to
understand why. A 15 minute improvement is _okay_ though for me still kind of in
the range of a micro-optimization (at least until I understand what's going on).

```
Executed in  153.72 mins    fish           external
   usr time  137.19 mins  172.00 micros  137.19 mins
   sys time   16.24 mins   35.00 micros   16.24 mins
```

### With two queries combined into a single query

Verdict: revert. I thought there was a chance this would be faster since the
`property` table might only have to be traversed once... I don't think this was
correct. I want to revisit this and look at the query with `EXPLAIN QUERY PLAN`
and see what the difference is.

```
Executed in  186.25 mins    fish           external
   usr time  185.80 mins  242.00 micros  185.80 mins
   sys time    0.26 mins   48.00 micros    0.26 mins
```

### With tables created manually so I can specify COLLATE NOCASE...

...per-column instead of per-query

Veridct: keep. It's slower, but I am kind of lazy, and may revert this later.
Because I don't need to preserve the original case of the data, I wonder if it
would be faster to just make everything uppercase.

```
Executed in  157.31 mins    fish           external
   usr time  138.38 mins  453.00 micros  138.38 mins
   sys time   18.14 mins   86.00 micros   18.14 mins
```

### With concurrency and integrity protections disabled

Veridct: keep. Slower overall, but it makes building the database itself a lot
faster, so I'll keep it for now.

(I accidentally lost the `time` output, but it was a little longer than the
above.)
