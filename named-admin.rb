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
  opts.banner = "Usage: named-admin COMMAND [argument] [options]"
  opts.program_name = "named-admin"
  opts.version = "1.1" 
  opts.separator ""
  opts.separator "List of Commands:"
  opts.separator ""
  opts.separator "  find [zone-name] \t\t Find zone(s) by name, asterix [*] can by used as wildcard"
  opts.separator "  count \t\t Count zones"
  opts.separator "  add [zone-name] \t Add a zone to the zone file"
  opts.separator "  remove [zone-name] \t Remove a zone from the zone file"
  opts.separator "  print \t\t Print all zones (parsed, sorted)"
  opts.separator "  parse \t\t Parse all zones and write them back to the zone file (parsed, sorted)"
  opts.separator ""
  opts.separator "Options:"

  # Define the options, and what they do
  options[:check] = true
  opts.on( '--[no-]check', 'Checks the configuration with named-checkconf after modifications (default: check)' ) do |check|
    options[:check] = check
  end

  options[:restart] = true
  opts.on( '--[no-]restart', 'Option to restart named after zone manipulations (default: restart)' ) do |restart|
    options[:restart] = restart
  end

  options[:file] = false
  opts.on( '-f', '--file FILE', 'Path to your named.conf file' ) do |file|
    options[:file] = file
  end

  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Output more information' ) do
    options[:verbose] = true
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
options[:arg] = ARGV[1]

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

na = NamedAdmin.new(options[:file], zone_tmpl, options[:verbose])

# indicator wheter the zone file file has been modified
file_modifications = false

# launch NamedAdmin with the option/parameters given
begin
  case options[:run]
  when "find"
    na.find_zones(options[:arg])
  when "remove"
    file_modifications = na.remove_zone(options[:arg])
  when "add"
    file_modifications = na.add_zone(options[:arg])
  when "parse"
    file_modifications = na.parse
  when "count"
    na.count_zones
  when "print"
    na.print_file
  else
    puts "Please provide an action argument."
    puts optparse.help
  end

  if file_modifications
    # launch named-checkconf ?
    if options[:check]
      na.named_checkconf
    else
      puts "You should check check your zone file with named-checkconf."
    end
    # restart named ?
    puts "Restart named for the changes to take effect."
    if options[:restart]
      na.named_restart()
    end
  end
rescue
  puts "An error occured during execution: #{$!}"
end
