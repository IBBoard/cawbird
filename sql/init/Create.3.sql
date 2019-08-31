PRAGMA user_version = 3;

ALTER TABLE `accounts`
ADD migrated INT DEFAULT 0;

CREATE TABLE IF NOT EXISTS `info`(
  key VARCHAR(40) PRIMARY KEY,
  value VARCHAR(255)
);