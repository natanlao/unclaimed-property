-- This database is effectively ephemeral, so we can squeeze out a little
-- more performance by disabling some data consistency / concurrency
-- safeguards.
PRAGMA journal_mode = off;
PRAGMA synchronous = off;
PRAGMA locking_mode = exclusive;

.import --csv '| xsv select PROPERTY_ID,PROPERTY_TYPE,CASH_REPORTED,SHARES_REPORTED,OWNER_NAME,OWNER_STREET_1,OWNER_CITY,OWNER_STATE,OWNER_ZIP,HOLDER_NAME property.csv | tr [:lower:] [:upper:]' property
.import --csv '| xsv select "First Name,Last Name,Home Street,Home City,Home State,Home Postal Code" people.csv | tr [:lower:] [:upper:]' people

.timer on

-- Find properties with familiar addresses
CREATE INDEX property_address ON property (OWNER_STREET_1);
SELECT COUNT(*), PROPERTY_ID, PROPERTY_TYPE, CASH_REPORTED, SHARES_REPORTED, OWNER_NAME, OWNER_STREET_1, OWNER_CITY, OWNER_STATE, OWNER_ZIP, HOLDER_NAME
FROM property
INNER JOIN people
ON property.OWNER_STREET_1 = people.`Home Street`
   AND people.`Home Street` != '';

-- Find properties with familiar names
CREATE INDEX property_owner ON property (OWNER_NAME);
SELECT COUNT(*), PROPERTY_ID, PROPERTY_TYPE, CASH_REPORTED, SHARES_REPORTED, OWNER_NAME, OWNER_STREET_1, OWNER_CITY, OWNER_STATE, OWNER_ZIP, HOLDER_NAME
FROM property
INNER JOIN people
ON (property.OWNER_NAME = people.`First Name` || ' ' || people.`Last Name`
    OR property.OWNER_NAME = people.`Last Name` || ' ' || people.`First Name`)
   AND people.`First Name` != ''
   AND people.`Last Name` != ''
   AND property.OWNER_NAME != '';

-- TODO: Try using IN for second query
-- TODO: Account for middle initial in name lookup
