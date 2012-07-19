#!/usr/bin/env ruby
require 'rubygems'
require 'system_timer'
require 'twitter'
require 'uri'
require 'net/http'
require 'json'

@credentials = []
@last_height = nil
@min_height = 0
@admins = ["man1", "adamcook124", "isaacgoldberg"]
@last_control = nil
@running = false

def get_creds
  f = File.new("creds", "r")
  while (line = f.gets)
    @credentials << line.strip
  end
  f.close
end

def tw_authorize
  Twitter.configure do |config|
    config.consumer_key = @credentials[0]
    config.consumer_secret = @credentials[1]
    config.oauth_token = @credentials[2]
    config.oauth_token_secret = @credentials[3]
  end
end

def get_aprs_data
  uri = URI.parse("http://api.aprs.fi/api/get?")
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Post.new(uri.request_uri)
  req["User-Agent"] = "SpaceBox (+http://twitter.com/liftsphere)"
  req["Content-Type"] = "application/json"
  req.set_form_data({
    "name" => @credentials[4], # callsign
    "what" => "loc",
    "apikey" => @credentials[5], # aprs.fi API key
    "format" => "json"
  })
  response = JSON.parse(http.request(req).body)
  if (response && response["found"] > 0)
    entries = response["entries"][0]
  else
    nil
  end
end

def get_tweet
  info = get_aprs_data
  return if !info
  feet = (3.28084 * info["altitude"]).floor
  link = "https://maps.google.com/maps?q=%s,+%s+(SpaceBox+balloon+altitude:+%d+feet)&iwloc=A&hl=en" % [info["lat"], info["lng"], feet]
  [link, feet]
end

def create_tweet
  tweet_info = get_tweet # [link, height]
  if (tweet_info[1] > @min_height && tweet_info[1] != @last_height)
    txt = "The balloon is now at %d feet, and %s! %s" % [tweet_info[1], @last_height && @last_height > tweet_info[1] ? "falling" : "rising", tweet_info[0]]
    p "Tweeting: %s" % [txt]
    Twitter.update(txt)
    @last_height = tweet_info[1]
  end
end

def handle_control_message
  lastdm = Twitter.direct_messages_received.first
  if (!@last_control)
    @last_control = lastdm.id
    return
  else
    if (@last_control != lastdm.id && @admins.include?(lastdm.sender.screen_name))
      # let's do it
      case lastdm.text.downcase
      when "go"
        p "Starting tweet stream!!!"
        @running = true
      when "stop"
        p "Stopping tweet stream..."
        @running = false
      when "kill"
        p "Killing app. G'bye!"
        exit
      end
      @last_control = lastdm.id
    end
  end
end

def main
  get_creds
  tw_authorize

  # main loop
  while true
    handle_control_message
    create_tweet if @running
    sleep(10)
  end
end

main
