PRAGMA user_version = 4;

ALTER TABLE `info`
ADD last_tweet_reply_id NUMERIC(19,0) DEFAULT 0;

ALTER TABLE `info`
ADD last_tweet_quote_id NUMERIC(19,0) DEFAULT 0;

