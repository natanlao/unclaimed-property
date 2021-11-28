-- This database is effectively ephemeral, so we can squeeze out a little
-- more performance by disabling some data consistency / concurrency
-- safeguards.
.timer on
PRAGMA journal_mode = off;
PRAGMA synchronous = off;
PRAGMA locking_mode = exclusive;

-- Create tables manually. `.import` will do this for us if we don't,
-- but doing it ourselves lets us specify COLLATE NOCASE on some columns
-- which makes SELECT a little faster.
CREATE TABLE "property"(
  "PROPERTY_ID" TEXT,
  "PROPERTY_TYPE" TEXT,
  "CASH_REPORTED" TEXT,
  "SHARES_REPORTED" TEXT,
  "OWNER_NAME" TEXT COLLATE NOCASE,
  "OWNER_STREET_1" TEXT COLLATE NOCASE,
  "OWNER_CITY" TEXT,
  "OWNER_STATE" TEXT,
  "OWNER_ZIP" TEXT,
  "HOLDER_NAME" TEXT
);
CREATE TABLE "people"(
  "First Name" TEXT COLLATE NOCASE,
  "Last Name" TEXT COLLATE NOCASE,
  "Home Street" TEXT COLLATE NOCASE,
  "Home City" TEXT,
  "Home State" TEXT,
  "Home Postal Code" TEXT
);

-- Import the CSVs, skipping the header row (which would otherwise be
-- imported since the tables we specified already exist.
-- TODO: Brittle coupling with table, headers
.import --csv --skip 1 '| xsv select PROPERTY_ID,PROPERTY_TYPE,CASH_REPORTED,SHARES_REPORTED,OWNER_NAME,OWNER_STREET_1,OWNER_CITY,OWNER_STATE,OWNER_ZIP,HOLDER_NAME property.csv'  property
.import --csv --skip 1 '| xsv select "First Name,Last Name,Home Street,Home City,Home State,Home Postal Code" people.csv' people

-- Find properties with familiar addresses
SELECT COUNT(*), PROPERTY_ID, PROPERTY_TYPE, CASH_REPORTED, SHARES_REPORTED, OWNER_NAME, OWNER_STREET_1,  OWNER_CITY, OWNER_STATE, OWNER_ZIP, HOLDER_NAME
FROM property
INNER JOIN people
ON property.OWNER_STREET_1 LIKE people.`Home Street`
    AND ifnull(people.`Home Street`, '') != '';
-- Using ifnull is supposedly better than checking length, but I'm not sold.
-- Tests don't show a big improvement either, but I'm too lazy to change it
-- back. .import doesn't insert NULL values (just empty strings) and I wonder
-- if it would be faster to just check equality against an empty string.

-- Find properties with familiar names
SELECT COUNT(*), PROPERTY_ID, PROPERTY_TYPE, CASH_REPORTED, SHARES_REPORTED, OWNER_NAME, OWNER_STREET_1,  OWNER_CITY, OWNER_STATE, OWNER_ZIP, HOLDER_NAME
FROM property
INNER JOIN people
ON (property.OWNER_NAME = people.`First Name` || ' ' || people.`Last Name`
    OR property.OWNER_NAME = people.`Last Name` || ' ' || people.`First Name`)
   AND ifnull(people.`First Name`, '') != ''
   AND ifnull(people.`Last Name`, '') != ''
   AND ifnull(property.OWNER_NAME, '') != '';

-- TODO: Try an index on OWNER_NAME
-- TODO: Is it possible to remove LIKE on OWNER_STREET_1?
-- TODO: Does casting PROPERTY_ID as INTEGER and setting it as primary key change anything?
-- TODO: Try using IN for second query
-- TODO: Try updating empty strings to NULL values / checkig only string equality
-- TODO: Try abandoning COLLATE NOCASE and make everything uppercase?
