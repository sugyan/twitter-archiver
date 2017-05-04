#!/usr/bin/env ruby
# require 'cgi'
require 'logger'
require 'pathname'
require 'set'
require 'twitter'

require 'searcher'

class Archiver
  def initialize(consumer_key, consumer_secret)
    @log = Logger.new(STDERR)
    @out_dir = Pathname(File.dirname(__FILE__)).join('..', 'out')
    @results = {}
    @twitter = Twitter::REST::Client.new do |config|
      config.consumer_key    = consumer_key
      config.consumer_secret = consumer_secret
    end
  end

  def run(target)
    collect_tweets(target)
    save_files(target)
  end

  private

  def collect_tweets(target)
    @log.info("search @#{target}'s tweets...")
    searcher = Searcher.new(target)
    yyyy_mm = nil
    tweets = []
    # tweet_ids = searcher.fetch(100)
    tweet_ids = searcher.fetch(30)
    @twitter.statuses(tweet_ids).sort { |a, b| b.id <=> a.id }.each do |tweet|
      ym = tweet.created_at.dup.localtime.strftime('%Y_%m')
      yyyy_mm = ym if yyyy_mm.nil?
      if yyyy_mm != ym
        save_tweets(tweets, yyyy_mm)
        tweets.clear
        yyyy_mm = ym
      end
      tweets << tweet
    end
    save_tweets(tweets, yyyy_mm)
  end

  def save_tweets(tweets, yyyy_mm)
    @log.debug("save #{yyyy_mm}")
    @results[yyyy_mm] = tweets.size
  end

  def save_files(target)
    save_payload_details
    save_tweet_index
    save_user_details(target)
  end

  def save_payload_details
    open(@out_dir.join('data', 'js', 'payload_details.js'), 'w') do |file|
      @log.info("write to #{file.path}")
      data = {
        tweets:     @results.values.inject(&:+),
        created_at: Time.now.to_s,
        lang: :en
      }
      file.puts("var payload_details = #{JSON.pretty_generate(data)}")
    end
  end

  def save_tweet_index
    open(@out_dir.join('data', 'js', 'tweet_index.js'), 'w') do |file|
      @log.info("write to #{file.path}")
      data = @results.keys.sort.reverse.map do |key|
        year, month = key.split(/_/, 2)
        {
          'file_name'   => "data/js/tweets/#{key}.js",
          'var_name'    => "tweets_#{key}",
          'tweet_count' => @results[key],
          'year'        => year.to_i,
          'month'       => month.to_i
        }
      end
      file.puts("var tweet_index = #{JSON.pretty_generate(data)}")
    end
  end

  def save_user_details(target)
    user = @twitter.user(target)
    open(@out_dir.join('data', 'js', 'user_details.js'), 'w') do |file|
      @log.info("write to #{file.path}")
      keys = %i[screen_name location id created_at]
      data = user.to_h.select { |k| keys.include?(k) }
      data[:full_name] = user.name
      data[:bio] = user.description
      file.puts("var user_details = #{JSON.pretty_generate(data)}")
    end
  end

  # def tweet2obj(tweet)
  #   obj = { 'id_str' => tweet.id.to_s }
  #   # required
  #   %w(source geo text id created_at).each do |key|
  #     obj[key] = tweet[key] || {}
  #   end
  #   # optional
  #   %w(in_reply_to_user_id in_reply_to_status_id in_reply_to_screen_name).each do |key|
  #     if tweet[key]
  #       obj[key] = tweet[key]
  #       if key.match(/_id$/)
  #         obj["#{key}_str"] = tweet[key].to_s
  #       end
  #     end
  #   end
  #   # entities
  #   obj['entities'] = {
  #     'user_mentions' => tweet.user_mentions.map{|e| e.to_hash },
  #     'media'         => tweet.media.map        {|e| e.to_hash },
  #     'hashtags'      => tweet.hashtags.map     {|e| e.to_hash },
  #     'urls'          => tweet.urls.map         {|e| e.to_hash },
  #   }
  #   # download media images
  #   dir = File.dirname(__FILE__) + '/../out/img/data/'
  #   obj['entities']['media'].each do |media|
  #     imgpath = CGI.escape(media[:media_url])
  #     @log.info('download: %s' % imgpath)
  #     begin
  #       open(media[:media_url]) do |src|
  #         open(dir + imgpath, 'wb') do |des|
  #           des.write(src.read)
  #         end
  #       end
  #     rescue => e
  #       @log.warn('failed: %s' % e)
  #     end
  #     media[:media_url] = './img/data/' + CGI.escape(imgpath)
  #     media[:media_url_https] = './img/data/' + CGI.escape(imgpath)
  #   end
  #   # user
  #   obj['user'] = { 'id_str' => tweet.user.id.to_s }
  #   %w(name screen_name protected profile_image_url_https id verified).each do |key|
  #     obj['user'][key] = tweet.user[key]
  #   end
  #   # retweeted
  #   if tweet.retweet?
  #     obj['retweeted_status'] = tweet2obj(tweet.retweeted_status)
  #   end
  #   # return
  #   obj
  # end

  #   dir = File.dirname(__FILE__) + '/../out/data/js/'
  #   # user details
  #   # index
  #   open(dir + 'tweet_index.js', 'wb') do |file|
  #     @log.info('write to tweet_index.js')
  #     data = results.keys.sort.reverse.map do |key|
  #       year, month = key.split(/_/, 2)
  #       {
  #         'file_name'   => "data/js/tweets/#{ key }.js",
  #         'var_name'    => "tweets_#{ key }",
  #         'tweet_count' => results[key].length,
  #         'year'        => year.to_i,
  #         'month'       => month.to_i,
  #       }
  #     end
  #     file.write('var tweet_index = ')
  #     file.write(JSON.pretty_generate(data))
  #   end
  #   # payload
  #   open(dir + 'payload_details.js', 'wb') do |file|
  #     @log.info('write to payload_details.js')
  #     data = {
  #       'tweets'     => results.map{|k,v| v.length }.reduce(:+),
  #       'created_at' => Time.now.to_s,
  #     }
  #     file.write('var payload_details = ')
  #     file.write(JSON.pretty_generate(data))
  #   end
  #   # tweets
  #   results.each do |key, value|
  #     file = "tweets/#{ key }.js"
  #     @log.info('write to ' + file)
  #     open(dir + file, 'wb') do |file|
  #       file.write("Grailbird.data.tweets_#{ key } = ")
  #       file.write(JSON.pretty_generate(value))
  #     end
  #   end
  # end
end
