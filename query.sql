.import --csv unclaimed_property.csv property
.import --csv contacts.csv people

SELECT * FROM property INNER JOIN people ON property.OWNER_STREET_1 LIKE people.`Home Street` WHERE length(people.`Home Street`) > 0;

SELECT * FROM property
  INNER JOIN people
    ON property.OWNER_NAME = people.`First Name` || ' ' || people.`Last Name` COLLATE NOCASE
    OR property.OWNER_NAME = people.`Last Name` || ' ' || people.`First Name` COLLATE NOCASE
  WHERE
    length(people.`First Name`) > 0
    AND length(people.`Last Name`) > 0
    AND length(property.OWNER_NAME) > 0;