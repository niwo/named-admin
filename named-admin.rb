#!/usr/bin/env ruby

#
# named-admin Copyright (C) 2009 Nik Wolfgramm
#

# resolve the application path
if File.symlink?(__FILE__)
  APP_PATH = File.dirname(File.readlink(__FILE__))
else
  APP_PATH = File.dirname(__FILE__)
end

require "yaml"
require "optparse"
require APP_PATH + "/lib/NamedAdmin"

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: named-admin COMMAND [options]"
  opts.program_name = "named-admin"
  opts.version = "1.1" 
  opts.separator ""
  opts.separator "List of Commands:"
  opts.separator ""
  opts.separator "  find [name] \t\t Find zone(s) by name, asterix [*] can by used as wildcard"
  opts.separator "  count \t\t Count zones"
  opts.separator "  add [zone-name] \t Add a zone to the zone file"
  opts.separator "  remove [zone-name] \t Remove a zone from the zone file"
  opts.separator "  print \t\t Print all zones (parsed, sorted)"
  opts.separator "  parse \t\t Parse all zones and write them back to the zone file (parsed, sorted)"
  opts.separator ""
  opts.separator "Options:"

  # Define the options, and what they do
  #opts.on( '-z', '--zone-name ZONE', 'Name of zone to manipulate' ) do |zone|
  #  options[:zone] = zone
  #end

  options[:check] = true
  opts.on( '--[no-]check', 'Checks the configuration with named-checkconf' ) do |check|
    options[:check] = check
  end

  options[:file] = false
  opts.on( '-f', '--file FILE', 'Path to your named.conf file' ) do |file|
    options[:file] = file
  end

  opts.on_tail("-?", "--help", "Display this screen" ) do
    puts opts
    exit
  end
  
  opts.on_tail("--version", "Show version") do
    puts "#{opts.program_name} v.#{opts.version}, written by Nik Wolfgramm"
    puts
    puts "Copyright (C) 2009 Nik Wolfgramm"
    puts "This is free software; see the source for copying conditions."
    puts "There is NO warranty; not even for MERCHANTABILITY or" 
    puts "FITNESS FOR A PARTICULAR PURPOSE."
    exit
  end
end

# get the command to execute
options[:run] = ARGV[0]

begin
  optparse.parse!
rescue OptionParser::InvalidOption
   print "Invalide option provided."
   puts optparse.help
  exit
end

if options[:run] == "add" && !File.exists?(APP_PATH + '/config/zones.yml')
  puts "Please create a zone template file in order to insert zones."
  puts "An example can be found at config/zones.yml.orig"
  exit
elsif !File.exists?(APP_PATH + '/config/zones.yml')
  zone_tmpl = {}
else
  zone_tmpl = YAML.load_file(APP_PATH + '/config/zones.yml' ) || {}
end

begin
  CONFIG = YAML.load_file(APP_PATH + '/config/config.yml' )
rescue
  "No config file found: " + $!
  exit
end

options[:file] = CONFIG['named.conf']['path'] unless options[:file]

na = NamedAdmin.new(options[:file], zone_tmpl)
do_checkconf = false

begin
  case options[:run]
  when "find"
    na.find_zones #(options[:zone])
  when "remove"
    na.remove_zone #(options[:zone])
    do_checkconf = true
  when "add"
    na.add_zone #(options[:zone])
    do_checkconf = true
  when "parse"
    na.parse
    do_checkconf = true
  when "count"
    na.count_zones
  when "print"
    na.print_file
  else
    puts "Please provide an action argument."
    puts optparse.help
  end
  if options[:check] && do_checkconf
    na.named_checkconf
  end
rescue
  puts "An error occured during execution: " + $!
end
