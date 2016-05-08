#!/usr/bin/env ruby
#
# askwiki.rb: Retrieve Wikipedia extract using the Wikipedia API
#
# Usage: askwiki.rb [KEYWORD ...]
#
# Author::    Andrew Henroid (mailto:ahenroid@gmail.com)
# Copyright:: Copyright (c) 2016 Andrew Henroid
# License::   MIT License
#

require "open-uri"
require "json"
require "nokogiri"

module Wiki #:nodoc
  # Entry for a single Wiki page
  class Entry
    # Full title
    attr_reader :title
    # Extract text
    attr_reader :extract

    # Class initializer
    # == Parameters
    # title:: Full title
    # extract:: Extract text (or nil if ambiguous)
    def initialize(title, extract)
      @title = title
      @extract = extract
    end

    # Format output text
    # == Parameters
    # cols:: Maximum output columns (default: 80)
    # indent:: Spaces to indent extract text (default: 2)
    # == Returns
    # Formatted string (multiple lines)
    def format(cols:80, indent:2)
      indent = " " * indent
      etxt = ""
      @extract.split("\n").map {|ln|
        buf = ""
        ln.strip.split(/\s+/).each {|s|
          if buf.length + 1 + s.length > cols
            etxt += "#{buf}\n"
            buf = ""
          end
          buf += buf.empty? ? indent:" "
          buf += s
        }
        etxt += "#{buf}\n" unless buf.empty?
      }
      @title + "\n" + etxt
    end
  end
  
  # Issue query to Wikipedia
  # == Parameters
  # keywords:: Query keyword string(s)
  # == Returns
  # Array of Entry objects or nil (no match). When resulting Entry.extract
  # is "nil" this indicates an ambiguous response (multiple possible topics)
  def self.query(*keywords)
    # build wikipedia query string
    uri = "https://en.wikipedia.org/w/api.php?"
    uri += "&action=query&format=json&redirects=1"
    uri += "&prop=extracts&exintro="
    uri += "&titles=" + keywords.join(" ").gsub(/\s+/, "%20")
    
    # parse JSON and extract HTML
    list  = []
    resp = open(uri).read
    json = JSON::parse(resp)
    json["query"]["pages"].values.each {|node|
      if !node["extract"].nil?
        extract = Nokogiri::HTML(node["extract"]).css("body").text
        extract = nil if extract =~ /(may|can) refer to:$/
        list.push(Entry.new(node["title"], extract))
      end
    }
    list.empty? ? nil:list
  end
end

#
# Test driver
#

(ME = $0).gsub!(/.*\//, "")

# parse command line options
while ARGV[0] =~ /^-/
  opt = ARGV.shift
  case opt
  when "--"
    break
  when /^(-h|--help)$/
    usage = true
    break
  else
    puts "#{ME}: unrecognized option `#{opt}'"
    usage = true
    break
  end
end

# display usage message and exit
if usage or ARGV.empty?
  puts "Usage: #{ME} [KEYWORD ...]"
  exit 1
end

# issue query and check response
data = Wiki::query(*ARGV)
if data.nil?
  puts "#{ME}: no match for `#{ARGV.join(' ')}'"
  exit 1
elsif data[0].extract.nil?
  puts "#{ME}: ambiguous response for `#{data[0].title}'"
  exit 1
end

# show results
puts data.map{|entry| entry.format}.join("\n")

exit 0
