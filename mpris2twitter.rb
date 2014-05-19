#!/usr/bin/ruby -w
# -*- coding: utf-8 -*-
require 'dbus'
require 'twitter'
require 'rubygems'
require 'yaml'

# read config.yml
config = YAML.load_file('./config.yml')

# mpris
# see the specification
#   http://specifications.freedesktop.org/mpris-spec/latest/

service_name = ''

# get dbus instance
dbus = DBus::SessionBus.instance

# get service name of mpris player
dbus.proxy.ListNames[0].each{|s|
  if s =~ /^org.mpris/
    service_name = s
    break
  end
}

# get service
service = dbus.service(service_name)

# mpris player object
player = service.object('/org/mpris/MediaPlayer2')

# introspect
begin
  player.introspect
rescue => e
  puts "Rhythmbox or other mpris player is not running."
  exit 1
end

# get interface and set default interface on bus
iface = player["org.freedesktop.DBus.Properties"]
player.default_iface = "org.freedesktop.DBus.Properties"

# catch the signal "PropertiesChanged"
player.on_signal("PropertiesChanged") {|i,property|

  if !property.key?("Metadata") || !property.key?("PlaybackStatus")
    next
  end
  if property["PlaybackStatus"] == "Stopped"
    next
  end

  # Metadata: http://www.freedesktop.org/wiki/Specifications/mpris-spec/metadata
  meta = property["Metadata"]
  album = meta["xesam:album"]
  trackNumber = meta["xesam:trackNumber"]
  title = meta["xesam:title"]
  length = meta["mpris:length"]

  artist = ""
  if meta["xesam:artist"].instance_of?(Array)
    meta["xesam:artist"].each{|v|
      artist += v
    }
  end

  albumArtist = ""
  if meta["xesam:artist"].instance_of?(Array)
    meta["xesam:artist"].each{|v|
      albumArtist += v
    }
  end

  t = Time.local(2000, 1, 1, 0, 0, 0, 0)
  t += length.div(1000000)
  length = t.strftime("%-M:%S")

  post = "I'm listening to #{title} by #{artist} on #{album} (#{length}) ♪ #nowplaying".force_encoding("UTF-8")
  # cut strings when strings to post is over 140
  if post.length > 140
    post = post.slice(0, 137) + '...'
  end

  client = Twitter::REST::Client.new {|c|
    c.consumer_key = config["consumer_key"]
    c.consumer_secret = config["consumer_secret"]
    c.access_token = config["access_token"]
    c.access_token_secret = config["access_token_secret"]
  }
  client.update(post)
}

loop = DBus::Main.new
loop << dbus
loop.run
