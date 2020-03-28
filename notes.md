# Notes

This file contains a variety of development notes that track how some bits of the code work.
This could be included in the doc strings, but doing that would generally repeat the description a lot.
Recording it here keeps it in one place.

## Translations

Translations are linked to [Transifex](https://www.transifex.com/cawbird/cawbird/dashboard/).

The base translation template is rebuilt using `ninja -C build cawbird-pot`.

Translations can then be rebuilt using `ninja -C build cawbird-update-po`. It may also rebuild the `.pot` file. It doesn't say so in the docs, but the file updates when it's run.

## Fake Streaming

Corebird was built for the Twitter streaming API. On 16th August 2018, Twitter closed down the API, which [broke lots of apps](http://apps-of-a-feather.com/). Twitter encouraged people to use the "Account Activity API", which was an Enterprise capability that cost thousands of dollars for even a small number of users. This was when Corebird was abandonned.

However, the older polling APIs remained. Rather than completely re-architect Corebird (or be forced to use the Twitter website **\*shudders\***) IBBoard decided to revert to the polling APIs but then still pass the messages to Corebird as if they were still streamed. This is how Cawbird continues to work.

There are four main streams:
* Timeline
* Mentions
* Favourites
* Direct Messages

Each of these has its own "user stream" function (`CbUserStream.c`) that fetches its messages, dispatches them and queues another poll of the API. These are all initiated in `cb_user_stream_start ()` and then scheduled at regular intervals using `g_timeout_add_seconds_full`.

The process of fake streaming by polling is:

* Create a `RestProxyCall` that knows which endpoint to talk to and invoke it asynchronously
* When the call ends, load the JSON object and find the array of tweets/DMs
* For each item in the array, starting from the end (oldest) and decrementing the counter:
  * Get the JsonOjbect (so we can pull values from it)
  * Determine its message type (DMs only)
  * Track the last ID (timeline/favourites/mentions) so that our next request can reference it
  * Send the tweet to the `stream_tweet()` function with the appropriate type to mimic a streamed tweet
* Wait for the next timeout

This fetches tweets on a schedule through polling, but still feeds them to the rest of the application one-by-one as if they had been streamed.

The `stream_tweet()` function iterates through all registered message receivers and dispatches the JSON node to each one in turn. These listeners implement `Cb.MessageReceiver` (in Vala) and are generally components like the `HomeTimeline`, `MentionsTimeline` and `DMThreadsPage`. Each receiver then implements the required method, which normally includes a series of `if (type == Cb.StreamMessageType.XXX) { … }` statements to ensure that only the required messages are handle (e.g. `MentionsTimeline` adds `Cb.StreamMessageType.MENTION` and deletes `Cb.StreamMessageType.DELETE`). This also means that we can pass all messages to all listeners and not worry about whether each listener is getting all the messages that it needs.

### Injecting tweets

In addition to streaming the real tweets received from Twitter, we sometimes want to inject our own tweets. This is particularly useful when composing tweets, because Twitter returns the JSON of the tweet that we just created and so we can show it before it arrives in the next poll. This makes it easier to compose threads.

Tweet injection is performed through the `cb_user_stream_inject_tweet()` function, which handles some special cases to make sure that the tweet is correct and fully formed.

## RT/Like/etc from user actions

The control flow for the RT, Like and other actions in TweetUtils is normally:

* User action (e.g. click) triggers a function call (`cb`)
* `cb` disables the button (makes it insensitive)
* Function calls `set_retweet_status.begin()` with an anoymous callback (`ac1`)
* `set_retweet_status` begins an async HTTP call with an anonymous (`ac2`)
* `set_retweet_status` `yields` and the user action function completes its outer block (which generally shouldn't do anything else because we've kicked off async methods and don't know what will happen)
* The HTTP request ends and calls the anonymous callback `ac2`
* `ac2` calls the HTTP call's `end()` function to retrieve the result
  * If this exceptions then an alert is shown and `set_retweet_status.callback()` is called to return execution to just after the `yield`
  * If the request was okay then the payload is retrieved, tweet flags are updated and `set_retweet_status.callback()` is called to return execution to just after the `yield`
* `set_retweet_status` completes and returns success/failure, which causes `ac1` to be called
* `ac1` calls `set_retweet_status.end (res)` to get the success/failure state, performs actions and completes
* `ac2` continues from after the `set_retweet_status.callback()` call (which generally does nothing, but could result in the "success" sub-path being run if the exception path doesn't `return` in its `catch` block!)

Note: if the call can fail/throw an exception then the callback should handle that and stop. Do not let the code
continue while thinking everything was okay! This causes odd behaviour like the RT button status not matching the RT status of the tweet.
