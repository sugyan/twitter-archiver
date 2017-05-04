require 'httpclient'
require 'nokogiri'
require 'open-uri'
require 'uri'

class Searcher
  def initialize(target)
    @target = target
    @ids = []
    @oldest = Float::INFINITY
    @fiber = Fiber.new do
      loop do
        search_ids
        Fiber.yield
        sleep 1
      end
    end
  end

  def fetch(n)
    size = @ids.size
    while @ids.size < n
      @fiber.resume
      raise 'zero tweets' if @ids.size == size
    end
    @ids.slice!(0, n)
  end

  private

  def build_url
    url = URI('https://twitter.com/search')
    params = {
      f: 'tweets',
      q: "from:#{@target}"
    }
    params[:max_position] = "TWEET-#{@oldest}-#{@oldest}" if @oldest < Float::INFINITY
    url.query = params.map { |k, v| "#{k}=#{v}" }.join('&')
    url.to_s
  end

  def search_ids
    url = build_url
    p url
    begin
      Nokogiri::HTML(HTTPClient.new.get(url).body).css('.tweet').each do |tweet|
        id = tweet['data-tweet-id']
        next if id.nil?
        @oldest = [id.to_i, @oldest].min
        @ids << id
      end
    rescue
      raise 'Error!' # TODO
    end
  end
end
