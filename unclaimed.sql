-- This database is effectively ephemeral, so we can squeeze out a little
-- more performance by disabling some data consistency / concurrency
-- safeguards.
PRAGMA journal_mode = off;
PRAGMA synchronous = off;
PRAGMA locking_mode = exclusive;

.import --csv '| xsv select PROPERTY_ID,PROPERTY_TYPE,CASH_REPORTED,SHARES_REPORTED,OWNER_NAME,OWNER_STREET_1,OWNER_CITY,OWNER_STATE,OWNER_ZIP,HOLDER_NAME property.csv | tr [:lower:] [:upper:]' property
.import --csv people.csv people

.timer on

-- Contacts can have an address listed as Home, Business, or Other.
CREATE VIEW addresses AS
    SELECT `First Name` AS first_name,
           `Last Name` AS last_name,
           UPPER(`Home Street`) AS street,
           UPPER(`Home City`) AS city,
           `Home Postal Code` AS zip_code
        FROM people
        WHERE street != ''
    UNION
    SELECT `First Name` AS first_name,
           `Last Name` AS last_name,
           UPPER(`Business Street`) AS street,
           UPPER(`Business City`) AS city,
           `Business Postal Code` AS zip_code
        FROM people
        WHERE street != ''
    UNION
    SELECT `First Name` AS first_name,
           `Last Name` AS last_name,
           UPPER(`Other Street`) AS street,
           UPPER(`Other City`) AS city,
           `Other Postal Code` AS zip_code
        FROM people
        WHERE street != '';

-- Find properties with familiar addresses
CREATE INDEX property_address ON property (OWNER_STREET_1, OWNER_CITY);
SELECT COUNT(*), PROPERTY_ID, PROPERTY_TYPE, CASH_REPORTED, SHARES_REPORTED, OWNER_NAME, OWNER_STREET_1, OWNER_CITY, OWNER_STATE, OWNER_ZIP, HOLDER_NAME
FROM property
INNER JOIN addresses
ON property.OWNER_STREET_1 = addresses.street
   AND property.OWNER_CITY = addresses.city;

-- Find properties with familiar names
CREATE INDEX property_owner ON property (OWNER_NAME);
SELECT COUNT(*), PROPERTY_ID, PROPERTY_TYPE, CASH_REPORTED, SHARES_REPORTED, OWNER_NAME, OWNER_STREET_1, OWNER_CITY, OWNER_STATE, OWNER_ZIP, HOLDER_NAME
FROM property
INNER JOIN people
ON (property.OWNER_NAME = UPPER(people.`First Name` || ' ' || people.`Last Name`)
    OR property.OWNER_NAME = UPPER(people.`Last Name` || ' ' || people.`First Name`))
   AND people.`First Name` != ''
   AND people.`Last Name` != ''
   AND property.OWNER_NAME != '';

-- TODO: Try using IN for second query
-- TODO: Account for middle initial in name lookup
