#!/usr/bin/env ruby

require 'cgi' # to unescape special characters
require 'iconv' # to convert to MacRoman
require 'open-uri'
require 'fileutils'
require 'find'
require 'rubygems'
require 'active_support'
require 'rexml/document'
require 'rexml/streamlistener'
include REXML
include FileUtils

FIVE_MINUTES = 5.minutes.to_i
ONE_HOUR = 1.hour.to_i
WIRE_LOC = "/home/apwire/Desktop/AP_WIRE"
LAST_RUN = "/var/local/apwire/last_wirefeed_run"
ID_LIST = "600588"
MAX_ITEMS = 500

USER = "editor@newspaper.com"
PASS = "reallysecurepassword"

AP_CATEGORIES = {
    "a" => "GENERAL NEWS",
    "b" => "SPECIAL EVENTS",
    "c" => "FEATURES",
    "d" => "FOOD",
    "e" => "ENTERTAINMENT",
    "f" => "FINANCIAL",
    "g" => "STATE SUMMARIES",
    "h" => "NATL-INTL HEADLINES",
    "i" => "INTERNATIONAL",
    "j" => "STATE HEADLINES",
    "k" => "COMMENTARY",
    "l" => "LIFESTYLE",
    "m" => "FARM",
    "n" => "STATE",
    "o" => "WEATHER",
    "p" => "POLITICS",
    "q" => "SCORES",
    "r" => "RACING",
    "s" => "SPORTS",
    "t" => "TRAVEL",
    "u" => "STATE-REGL",
    "v" => "ADVISORY",
    "w" => "WASHINGTON",
    "x" => "UNKNOWN-X",
    "y" => "UNKNOWN-X",
    "z" => "UNKNOWN-X"
    }

def ap_url(time_interval)
    return "http://syndication.ap.org/AP.Distro.Feed/GetFeed.aspx?" +
    "idList=#{ID_LIST}&idListType=savedsearches&maxItems=#{MAX_ITEMS}&minDateTime=" +
    time_interval.utc.strftime("%Y-%m-%dT%H:%M:%SZ") +
    "&maxDateTime=&fullContent=hnews"
end

class Listener
    def initialize
        @story = []
        @name = ""
        @in_story = false
        @title = []
    end

    def tag_start(name, attr_hash)
        @name = name
        @in_story = true if @name == "content"
        @story << " " if @in_story == true && @name == "span"
        @name = name
        @category = attr_hash["Value"] if @name == "apcm:SubjectClassification" and attr_hash["Authority"] == "AP Category Code"
    end

    def text(str)
        @story << str.strip.gsub(/^[^A-Za-z0-9\(]+/,"") if @in_story
        @title << str.strip if @name == "apcm:SlugLine" and not @in_story
    end
    
    def in_content
        @in_story = false
        unescaped = CGI.unescape(@story.join) # in case AP really uses escaped XML chars like they should
        multibyte = ActiveSupport::Multibyte::Chars.new(unescaped) #convert to unicode string via Rails' ActiveRecord
        x = multibyte.normalize(:kc).to_s #convert multibyte chars to ASCII
        y = []
        x.split("/").each do |f|  #add space between whole number and fraction
            if f.length > 1 and f[-1].chr =~ /[0-9]/
                y << "#{f[0..-2]} #{f[-1].chr}"
            else
                y << f
            end
        end
        x = y.join("/")
        begin
            return Iconv.conv("MACINTOSH","UTF-8",x)
        rescue
            return x
        end
    end
    
    def complete_entry
        filename = @title.join.strip.gsub(/[^A-Za-z0-9\-\s]/,"")
        dir = "#{WIRE_LOC}/#{AP_CATEGORIES[@category]}"
        mkdir_p(dir)
        puts "Writing #{dir}/#{filename}.txt"
        begin
            File.open("#{dir}/#{filename}.txt", "w") {|f| f << @content}
        rescue
            puts "Error writing #{dir}/#{filename}.txt"
        end
        @story = []
        @title = []
    end

    def tag_end(name)
        case name
            when "p","tr","div","span",/h[0-9]/ then @story << "\r"
            when "td" then @story << "\t"
            when "content" then @content = self.in_content
            when "entry" then self.complete_entry
        end
    end
end
last_time = File.exists?(LAST_RUN) ? File.stat(LAST_RUN).mtime : 5.minutes.ago
last_clean = Time.now

while true
   stream_handler = Listener.new
   puts "Ingesting feed"
   time_now = Time.now
   begin
	   puts ap_url(last_time)
	   f=open(ap_url(last_time), :http_basic_authentication  => [USER, PASS]).readlines[1..-1].join
	   last_time = time_now
	   g = File.open("feed.xml","w")
	   g.write(f)
	   g.close
	   parser = Parsers::StreamParser.new(f, stream_handler)
	   parser.parse
       touch(LAST_RUN)
   rescue
	   puts "ERROR: could not open webfeed at this time."
   end
   puts "Sleeping for five minutes"
   if last_clean >= 1.hour.ago
       last_clean = Time.now
       Find.find(WIRE_LOC) do |f|
           if File.file?(f)
               begin
                   rm(f) if File.stat(f).mtime <= 3.days.ago
               rescue
                   puts "ERROR: could not remove #{f} at this time.  Will try again later."
               end
           end
       end
   end
   sleep FIVE_MINUTES
end

