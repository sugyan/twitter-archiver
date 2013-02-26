#!/usr/bin/env ruby

abort("usage: #{__FILE__} <twitter id>") unless ARGV.size > 0

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'archiver'

Archiver.new.start(ARGV.shift)
