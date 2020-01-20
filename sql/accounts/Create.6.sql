PRAGMA user_version = 6;

ALTER TABLE `user_cache`
ADD verified INTEGER(1) NOT NULL DEFAULT 0;

ALTER TABLE `user_cache`
ADD protected_account TINYINT NOT NULL DEFAULT 0;