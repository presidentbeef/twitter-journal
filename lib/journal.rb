require 'twitter'
require_relative '../db/schema'

def log message
  $stderr.puts "#{Time.now} - #{message}"
end

class Journal
  def initialize db = DB, config = JournalConfig
    @db = db
    @config = config
    @twitter = Twitter::REST::Client.new do |conf|
      conf.consumer_key = @config[:consumer_key]
      conf.consumer_secret = @config[:consumer_secret]
      conf.access_token  = @config[:access_token]
      conf.access_token_secret = @config[:access_token_secret]
    end
  end

  def tweets_by_day
    @db[:tweets].reverse(:created_at).all.group_by do |tweet|
      tweet[:created_at].strftime("%B %-d, %Y")
    end
  end

  # Returns true if there are any Tweets at all in the database
  def any_tweets?
    @db[:tweets].count > 0
  end

  def latest_stored_tweet_id
    @db[:tweets].select(:tweet_id).order(:created_at).last[:tweet_id]
  end

  # Fetch and store any new Tweets since the last Tweet
  def fetch_and_store_latest
    opts = if any_tweets?
             { since_id: latest_stored_tweet_id }
           else
             {}
           end

    tweets = fetch_tweets(opts)

    log "Found #{tweets.length} new tweet(s)"

    tweets.each do |tweet|
      store_tweet tweet
      store_hashtags tweet
    end
  end

  # Fetch tweets. Options are passed to the Twitter library.
  # Mostly used to set the newest Tweet seen.
  def fetch_tweets opts = {}
    opts = {
      trim_user: true,
      tweet_mode: "extended",
      count: 200
    }.merge!(opts)

    log "Fetching tweets #{opts.inspect}"

    @twitter.user_timeline @config[:username], opts
  end

  # Search tweets for the given text
  def search text
    @db[:tweets].where(Sequel.like(:text, "%#{@db[:tweets].escape_like(text)}%"))
  end

  # Search tweets for the given hashtag
  def find_hashtag hashtag
    DB[:tweets].join(:hash_tags_tweets, tweet_id: :tweet_id).join(:hash_tags, id: :hash_tag_id).where(Sequel[:hash_tags][:text] => hashtag)
  end

  # Store the hashtags from a Tweet into the database
  def store_hashtags tweet
    tweet_id = tweet.id.to_s

    tweet.hashtags.each do |ht|
      if hash_tag_entry = @db[:hash_tags].where(text: ht.text).first
        hash_tag_id = hash_tag_entry[:id]
      else
        hash_tag_id = @db[:hash_tags].insert(text: ht.text)
      end

      @db[:hash_tags_tweets].insert(tweet_id: tweet_id, hash_tag_id: hash_tag_id)
    end
  end

  # Save an individual Tweet to the database if it does not already exist
  def store_tweet tweet
    tweet_id = tweet.id.to_s

    h = {
      created_at: tweet.created_at,
      text: tweet.attrs[:full_text],
      tweet_id: tweet_id
    }

    unless @db[:tweets].where(tweet_id: tweet_id).count > 0
      @db[:tweets].insert h
    end
  end
end
