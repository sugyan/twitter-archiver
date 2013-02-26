#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'logger'
require 'pit'
require 'twitter'

class Archiver
  def initialize
    @log = Logger.new(STDERR)
    config = Pit.get('twitter.com', :require => {
      'consumer_key'        => 'your consumer key',
      'consumer_secret'     => 'your consumer key secret',
      'access_token'        => 'your access token',
      'access_token_secret' => 'your access token secret',
    })
    @twitter = Twitter::Client.new(
      :consumer_key       => config['consumer_key'],
      :consumer_secret    => config['consumer_secret'],
      :oauth_token        => config['access_token'],
      :oauth_token_secret => config['access_token_secret'],
    )
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
    results = []
    @twitter.user_timeline(id, :count => 50, :contributor_details => true).each do |tweet|
      results.push(tweet2obj(tweet))
    end

    open(File.dirname(__FILE__) + '/../data/js/tweets/' + '2013_02.js', 'wb') do |des|
      des.write('Grailbird.data.tweets_2013_02 = ')
      des.write(JSON.pretty_generate(results))
    end
  end
end
