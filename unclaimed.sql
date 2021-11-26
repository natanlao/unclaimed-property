-- This database is effectively ephemeral, so we can squeeze out a little
-- more performance by disabling some data consistency / concurrency
-- safeguards.
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
  "NAME_OF_SECURITIES_REPORTED" TEXT,
  "DATE_REPORTED" TEXT,
  "NO_OF_OWNERS" TEXT,
  "OWNER_NAME" TEXT COLLATE NOCASE,
  "OWNER_STREET_1" TEXT COLLATE NOCASE,
  "OWNER_STREET_2" TEXT,
  "OWNER_STREET_3" TEXT,
  "OWNER_CITY" TEXT,
  "OWNER_STATE" TEXT,
  "OWNER_ZIP" TEXT,
  "OWNER_COUNTRY_CODE" TEXT,
  "CURRENT_CASH_BALANCE" TEXT,
  "NUMBER_OF_PENDING_CLAIMS" TEXT,
  "NUMBER_OF_PAID_CLAIMS" TEXT,
  "DATE_OF_LAST_CONTACT" TEXT,
  "HOLDER_NAME" TEXT,
  "HOLDER_STREET_1" TEXT,
  "HOLDER_STREET_2" TEXT,
  "HOLDER_STREET_3" TEXT,
  "HOLDER_CITY" TEXT,
  "HOLDER_STATE" TEXT,
  "HOLDER_ZIP" TEXT,
  "CUSIP" TEXT
);
CREATE TABLE "people"(
  "Title" TEXT,
  "First Name" TEXT COLLATE NOCASE,
  "Last Name" TEXT COLLATE NOCASE,
  "Nick Name" TEXT,
  "Company" TEXT,
  "Department" TEXT,
  "Job Title" TEXT,
  "Business Street" TEXT,
  "Business Street 2" TEXT,
  "Business City" TEXT,
  "Business State" TEXT,
  "Business Postal Code" TEXT,
  "Business Country" TEXT,
  "Home Street" TEXT COLLATE NOCASE,
  "Home Street 2" TEXT,
  "Home City" TEXT,
  "Home State" TEXT,
  "Home Postal Code" TEXT,
  "Home Country" TEXT,
  "Other Street" TEXT,
  "Other Street 2" TEXT,
  "Other City" TEXT,
  "Other State" TEXT,
  "Other Postal Code" TEXT,
  "Other Country" TEXT,
  "Business Fax" TEXT,
  "Business Phone" TEXT,
  "Business Phone 2" TEXT,
  "Home Phone" TEXT,
  "Home Phone 2" TEXT,
  "Mobile Phone" TEXT,
  "Other Phone" TEXT,
  "Pager" TEXT,
  "Birthday" TEXT,
  "E-mail Address" TEXT,
  "E-mail 2 Address" TEXT,
  "E-mail 3 Address" TEXT,
  "Notes" TEXT,
  "Web Page" TEXT,
  "User 1" TEXT
);

-- Import the CSVs, skipping the header row (which would otherwise be
-- imported since the tables we specified already exist.
.import --csv --skip 1 unclaimed_property.csv property
.import --csv --skip 1 contacts.csv people

-- Find properties with familiar addresses
SELECT PROPERTY_ID, PROPERTY_TYPE, CASH_REPORTED, SHARES_REPORTED, OWNER_NAME, OWNER_STREET_1,  OWNER_CITY, OWNER_STATE, OWNER_ZIP, HOLDER_NAME
FROM property
INNER JOIN people
ON property.OWNER_STREET_1 LIKE people.`Home Street`
    AND ifnull(people.`Home Street`, '') != '';
-- Using ifnull is supposedly better than checking length, but I'm not sold.
-- Tests don't show a big improvement either, but I'm too lazy to change it
-- back. .import doesn't insert NULL values (just empty strings) and I wonder
-- if it would be faster to just check equality against an empty string.

-- Find properties with familiar names
SELECT PROPERTY_ID, PROPERTY_TYPE, CASH_REPORTED, SHARES_REPORTED, OWNER_NAME, OWNER_STREET_1,  OWNER_CITY, OWNER_STATE, OWNER_ZIP, HOLDER_NAME
FROM property
INNER JOIN people
ON (property.OWNER_NAME = people.`First Name` || ' ' || people.`Last Name`
    OR property.OWNER_NAME = people.`Last Name` || ' ' || people.`First Name`)
   AND ifnull(people.`First Name`, '') != ''
   AND ifnull(people.`Last Name`, '') != ''
   AND ifnull(property.OWNER_NAME, '') != '';
