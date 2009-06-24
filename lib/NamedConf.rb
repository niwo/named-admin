#!/usr/bin/env ruby

#
# named-admin Copyright (C) 2008 Nik Wolfgramm, licensed under GPL
#
# = NamedConf.rb: Classes for handling a bind named.conf configuration file
# Reads, writes and sorts the file and finds, inserts, deletes and counts zones
#

class NamedConf
  attr_accessor :zones, :head, :tail

  def initialize(file)
    @file = file
    @zones = Array.new
    @head = ''
    @tail = ''
  end

  def read
    if File.readable?(@file)
      comments = ''
      f = File.new(@file, "r")
      while (line = f.gets)
        # is there a comment?
        if line[/^ *(\/\/)|(#)|( *\/\*.*\*\/ *$)/] 
          comments << line
        # is it a multi line comment?
        elsif line[/(\/\*)/]
          comments << line
          while(line = f.gets)
            comments << line
            break if line =~ /.*\*\/ *$/
          end
        # is it a zone declaration?
        elsif line[/ *(zone) +/]
          line =~ / *(zone) +"(.+)"( +[A-Za-z]+)? *\{/
          zone = Zone.new($2, $3)
          zone.comments << comments unless comments == ''
          comments = ''
          # read zone options until end of zone is found
          while(line = f.gets)
            break if line =~ /^\};$/
            line =~ /([a-z-]+) +(.+);$/
            zone.options << {$1 => $2}
          end
          @zones << zone
        # must be something else...
        else
          unless line[/^$/]
            @zones.empty? ? (@head << comments + line) : (@tail << comments + line)
            comments = ''
          end
        end
      end
      f.close
      return true
    else
      raise "Error: file #{@file} is not readable."
    end
  end
  
  def print
    out = ''
    out << @head
    out << "\n"
    for zone in @zones
      out << zone.print
      out << "\n"
    end
    out << @tail
  end

  def to_s
    return print
  end

  def write
    self.sort_zones
    if File.writable?(@file)
      file = File.new(@file, 'w')
      begin
        file.print(self.print)
        file.close
      rescue
        file.close
        raise "Error: #{@file} write error."
      end
      return true
    else
      raise "Error: #{@file} not writable."
    end
  end

  def sort_zones
    @zones.sort! {|z1, z2| z1.name <=> z2.name }
  end

  def find_zone(name)
    return @zones.find {|z| z.name == name }
  end

  def delete_zone(name)
    zone = find_zone(name)
    if zone
      @zones.slice!(@zones.index(zone))
      return true
    else
      return false
    end
  end

  def insert_zone(name, options)
    unless find_zone(name)
      zone = Zone.new(name)
      zone.options = options
      @zones << zone
      return true
    else
      return false
    end
  end

  class Zone
    attr_accessor :name, :zclass, :comments, :options

    def initialize(name, zclass = 'IN', comments = '', *options)
      @name = name
      zclass == nil || zclass.empty?  ? @zclass = 'IN' : @zclass = zclass.strip
      options ? @options = [] : @options = options
      @comments = comments
    end
    
    def print
      out = "zone \"#{@name}\" #{@zclass} {\n"
      out = comments << out unless comments.empty?
      for option in @options
        option.each {|key, value|
          # remove all white spaces
          value.gsub!(/\s+/, '')
 	  # insert white spaces after/before curly brackets
          value.gsub!(/(\{)(\S+)/) { '{ ' + $2 }
          value.gsub!(/(.+\S+)(\})/) { $1 + ' }' }
          # insert white space after semicolons
          value.gsub!(/(;)(\S)/) { $1 + ' ' + $2 }
          # finally insert the full option string
	  out << "  #{key} #{value};\n"}
      end
      out << "};\n"
    end

    def to_s
      out = "---------------------------------\n"
      out << self.print
      out << '---------------------------------'
    end
  end
end
