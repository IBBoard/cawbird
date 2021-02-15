PRAGMA user_version = 4;

ALTER TABLE `accounts`
ADD token VARCHAR(100);

ALTER TABLE `accounts`
ADD token_secret VARCHAR(100);

ALTER TABLE `accounts`
ADD consumer_key VARCHAR(100);

ALTER TABLE `accounts`
ADD consumer_secret VARCHAR(100);