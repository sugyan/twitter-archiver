#!/usr/bin/env ruby

abort("usage: #{__FILE__} <Twitter ID (screen_name)>") if ARGV.empty?

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'archiver'

consumer_key = ENV['CONSUMER_KEY']
consumer_secret = ENV['CONSUMER_SECRET']
Archiver.new(consumer_key, consumer_secret).run(ARGV[0])
