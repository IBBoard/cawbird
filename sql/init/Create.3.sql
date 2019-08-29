PRAGMA user_version = 3;

ALTER TABLE `accounts`
ADD migrated INT DEFAULT 0;