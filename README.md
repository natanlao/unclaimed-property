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
  `property.csv`.
* A CSV of your contacts in Outlook format saved as `people.csv`. (Check
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
sqlite3 ':memory:' < unclaimed.sql
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
4. ~~Trim data loaded into SQLite so that the entire database can live in memory.~~


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


### `EXPLAIN` and `EXPLAIN QUERY PLAN`

The gist:

* Queries are evaluated / compiled / translated into "query plans".
* The query plan is what is executed.
* Seeing the query plan is very quick and can give me a window into query
  performance without actually running the entire query.

Didn't start doing this until late in the game, and I kind of want to go back
and look at all the query plans for these queries.


### `.timer on`

SQLite has a built in query timer, which would have been better to use so I
could see which operations in particular were affected by the changes I made.


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

### All of the above, with only relevant columns imported

Verdict: keep. Already decently faster even if the database is on disk but the
real purpose of this change is to reduce the size of the database so it's small
enough to fit in memory.

#### Database built on disk

```
Executed in  144.72 mins    fish           external
   usr time  135.17 mins    0.00 micros  135.17 mins
      sys time   10.12 mins  520.00 micros   10.12 mins
```

#### Database built in memory

This is really weird to me, for obvious reasons. Still digging into what the
problem is here.

```
Executed in  153.93 mins    fish           external
   usr time  154.52 mins  218.00 micros  154.52 mins
   sys time    0.14 mins   31.00 micros    0.14 mins
```

### Actually using indexes

In my defense, I tried using indexes at the very beginning and I couldn't get it
to work -- any query that utilized an index would return no results, so I
decided I would try again later.

I tried it again, and performance, as you might expect, changed drastically. I
still have no idea what I did differently:

```
Executed in  251.01 secs    fish           external
   usr time  265.82 secs  189.00 micros  265.82 secs
   sys time   17.25 secs   36.00 micros   17.25 secs
```

Those times are with the database built on disk. It is faster than doing so in
memory. I still don't understand why.

An interesting detail is that in the process of adding indexes, I tightenedd the
address query criterion from `property.OWNER_STREET_1 LIKE Home Street' to
`property.OWNER_STREET_1 = Home Street` and got the same results back. Maybe
this is a fluke. I have more work to do with addresses, anyway, so I'll leave it
there for now.

## In retrospect

If I did this again from the beginning, I would:

* Better document the changes that I made.
* Use `COUNT(*)` to ensure that queries were returning the same results each
  time with the changes I made.
* Use `.timer` and some arithmetic to better evaluate impact of the changes I
  made.
* Use `EXPLAIN QUERY PLAN` to get some window into how my changes would impact
  performance instead of throwing something at the wall then coming back in two
  hours to see if it stuck.

Lessons learned.
I'm not going to run the tests again, though, because I don't really want to.

