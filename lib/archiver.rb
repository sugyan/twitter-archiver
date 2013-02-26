#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'logger'
require 'pit'
require 'twitter'

class Archiver
  def initialize
    @log = Logger.new(STDERR)
    config = Pit.get('twitter.com', :require => {
      :consumer_key       => 'your consumer key',
      :consumer_secret    => 'your consumer key secret',
      :oauth_token        => 'your access token',
      :oauth_token_secret => 'your access token secret',
    })
    @twitter = Twitter::Client.new(config)
  end

  def tweet2obj(tweet)
    obj = { 'id_str' => tweet.id.to_s }
    # required
    %w(source geo text id created_at).each do |key|
      obj[key] = tweet[key] || {}
    end
    # optional
    %w(in_reply_to_user_id in_reply_to_status_id in_reply_to_screen_name).each do |key|
      if tweet[key]
        obj[key] = tweet[key]
        if key.match(/_id$/)
          obj["#{key}_str"] = tweet[key].to_s
        end
      end
    end
    # entities
    obj['entities'] = {
      'user_mentions' => tweet.user_mentions.map{|e| e.to_hash },
      'media'         => tweet.media.map        {|e| e.to_hash },
      'hashtags'      => tweet.hashtags.map     {|e| e.to_hash },
      'urls'          => tweet.urls.map         {|e| e.to_hash },
    }
    # user
    obj['user'] = { 'id_str' => tweet.user.id.to_s }
    %w(name screen_name protected profile_image_url_https id verified).each do |key|
      obj['user'][key] = tweet.user[key]
    end
    # retweeted
    if tweet.retweet?
      obj['retweeted_status'] = tweet2obj(tweet.retweeted_status)
    end
    # return
    obj
  end

  def start(id)
    results = {}
    @log.info('fetch timeline')
    max_id = nil
    while true do
      @log.info('max_id: ' + max_id.to_s)
      options = { :count => 200 }
      options[:max_id] = max_id if max_id
      tweets = @twitter.user_timeline(id, options)
      @log.info('%s tweets fetched' % tweets.length)
      break if tweets.length == 0
      tweets.each do |tweet|
        yyyy_mm = sprintf('%04d_%02d', tweet.created_at.year, tweet.created_at.month)
        (results[yyyy_mm] ||= []).push(tweet2obj(tweet))
      end
      sleep 1
      max_id = tweets[-1].id - 1
    end

    dir = File.dirname(__FILE__) + '/../out/data/js/'
    # user details
    open(dir + 'user_details.js', 'wb') do |file|
      @log.info('write to user_details.js')
      user = @twitter.user(id)
      file.write('var user_details = ')
      file.write(JSON.pretty_generate({
        'screen_name' => user.screen_name,
        'location'    => user.location,
        'full_name'   => user.name,
        'bio'         => user.description,
        'id'          => user.id.to_s,
        'created_at'  => user.created_at,
      }))
    end
    # index
    open(dir + 'tweet_index.js', 'wb') do |file|
      @log.info('write to tweet_index.js')
      data = results.keys.sort.reverse.map do |key|
        year, month = key.split(/_/, 2)
        {
          'file_name'   => "data/js/tweets/#{ key }.js",
          'var_name'    => "tweets_#{ key }",
          'tweet_count' => results[key].length,
          'year'        => year.to_i,
          'month'       => month.to_i,
        }
      end
      file.write('var tweet_index = ')
      file.write(JSON.pretty_generate(data))
    end
    # payload
    open(dir + 'payload_details.js', 'wb') do |file|
      @log.info('write to payload_details.js')
      data = {
        'tweets'     => results.map{|k,v| v.length }.reduce(:+),
        'created_at' => Time.now.to_s,
      }
      file.write('var payload_details = ')
      file.write(JSON.pretty_generate(data))
    end
    # tweets
    results.each do |key, value|
      file = "tweets/#{ key }.js"
      @log.info('write to ' + file)
      open(dir + file, 'wb') do |file|
        file.write("Grailbird.data.tweets_#{ key } = ")
        file.write(JSON.pretty_generate(value))
      end
    end
  end
end
