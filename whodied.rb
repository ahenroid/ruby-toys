#!/usr/bin/env ruby
#
# whodied.rb: Scrape notable death entries from Wikipedia
#
# Usage: whodied.rb [MONTH/YEAR ...]
#
# Author::    Andrew Henroid (mailto:ahenroid@gmail.com)
# Copyright:: Copyright (c) 2016 Andrew Henroid
# License::   MIT License
#

require "open-uri"
require "nokogiri"

module WhoDied #:nodoc
  # Entry for a single death
  class Dead
    # Full name of the deceased (String)
    attr_reader :name
    # Age at time of death (Integer)
    attr_reader :age
    # Date of death (Date)
    attr_reader :date
    # Cause of death (String)
    attr_reader :cause
    # Additional background (String)
    attr_reader :info

    # Class initializer
    # == Parameters
    # name:: Full name of the deceased (String)
    # age:: Age at time of death (Integer)
    # date:: Date of death (Date)
    # cause:: Cause of death (String)
    # info:: Additional background (String)
    def initialize(name:"", age:"", date:"", cause:"", info:"")
      @name = name
      @age = age
      @date = date
      @cause = cause
      @info = info
    end
    
    # Cast to String object
    def to_s
      cause = @cause.nil? ? "":",#{@cause}"
      "#{@date.to_s}: #{@name} (#{@age}#{cause}): #{@info}"
    end
  end

  # Parse HTML entries into an Array of Dead objects
  # == Parameters
  # html:: Nokogiri::HTML object
  # year:: Year
  # == Returns
  # Array of Dead objects
  def Dead::parse(html, year)
    list = []
    date = nil
    
    html.css("a[title]").each {|node|
      parent = node.parent
      
      case parent.name
      when "span"
        # extract date from <h3><span> entry and continue
        if parent.parent.name.eql?("h3")
          month, day = node["title"].split(/\s+/)
          if day =~ /^\d+$/
            date = Date.new(year, Date::MONTHNAMES.index(month), day.to_i)
          end
        elsif  parent.parent.name.eql?("h2")
          month, yr = node["title"].split(/\s+/).values_at(-2, -1)
          year = yr.to_i if yr =~ /^\d+$/
        end
        next
      when "li"
        # node must be first child of <li>
        next unless (parent.children[0] == node)
      else
        # ignore all other elements
        next
      end
      
      # replace commas in () with ; (to avoid issues with next split op)
      txt = parent.text.gsub(/\([^\(\)]+\)/) do |substr|
        substr.gsub(",", ";")
      end
      
      # remove references in []
      txt.gsub!(/\s*\[\d+\]\s*/, "")
      # remove trailing .
      txt.gsub!(/\s*\.\s*$/, "")
      
      # extract fields
      name, age, info, cause = txt.split(/\s*,\s*/).values_at(0..2, -1)
      next if age.nil? or info.nil?
      
      # fix-up age and cause fields
      unless age =~ /^\d+$/
        info = age
        age = nil
      end
      cause = nil if cause =~ /\)\s*$/ or cause.eql?info or cause.empty?
      
      # clean-up name and info text
      name.gsub!(/\s*\([^\(\)]*\)\s*/, " ")
      name.gsub!(/\s\s*/, " ")
      info.gsub!(/\s*\([^\(\)]*\)\s*/, " ")
      info.gsub!(/\s*\.\s*$/, "")
      info.gsub!(/\s\s*/, " ")
      
      list.push(Dead.new(name:name, age:age, date:date, cause:cause, info:info))
    }
    
    return list
  end

  # Merge and remove duplicates from a list of Dead objects
  # == Parameters
  # list:: Array of Dead objects
  # == Returns
  # Array of Dead objects
  def Dead::merge(list)
    # build hash list
    hash = {}
    list.each {|entry|
      hash["#{entry.date.to_s}:#{entry.name}"] = entry
    }
    
    # sort keys by hash entry date
    keys = hash.keys.sort {|x, y| (hash[y].date <=> hash[x].date)}
    
    return keys.map {|key| hash[key]}
  end
  
  # Issue queries to Wikipedia
  # == Parameters
  # dates:: Date selector strings (MONTH/YEAR ...)
  # == Returns
  # Array of Dead objects
  def self.query(*dates)
    list = []
    dates = [nil] if dates.empty?
    dates.each {|date|
      # convert date selector to Wikipedia URI
      uri = "https://en.wikipedia.org/wiki/"
      year = nil
      if date =~ /^(\d+)(\/(\d*))?$/
        (month, year) = date.split(/\//)
        if year.nil?
          year = month.to_i
          month = 1
        else
          year = year.to_i
          month = month.to_i
        end
        year = (year + 2000) if year < 100
        uri += Date.new(year, month).strftime("Deaths_in_%B_%Y")
      else
        year = Date.today.year
        uri += "Deaths_in_#{year}"
      end

      # load HTML
      html = Nokogiri::HTML(open(uri).read)
      
      # parse HTML and return Dead objects
      Dead.parse(html, year).each {|entry| list.push(entry)}
    }
    Dead::merge(list)
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
  when /^(-h|--help)$/
    usage = true
  when "--"
    break
  else
    puts "#{ME}: unrecognized option `#{opt}'"
    usage = true
    break
  end
end

# display usage message
if usage
  puts "Usage: #{ME} [MONTH/YEAR ...]"
  exit 1
end

puts WhoDied::query(*ARGV)

exit 0

