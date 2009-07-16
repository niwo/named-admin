#!/usr/bin/env ruby

#
# named-admin Copyright (C) 2009 Nik Wolfgramm
#

# resolve the application path
if File.symlink?(__FILE__)
  APP_PATH = File.expand_path(File.dirname(File.readlink(__FILE__)))
else
  APP_PATH = File.expand_path(File.dirname(__FILE__))
end
$: << File.expand_path(APP_PATH, "/../lib")

require "yaml"
require "optparse"
require "lib/NamedAdmin"

options = {}
options[:na_conf_file] = APP_PATH + "/config/config.yml"
options[:zone_tmpl_file] = APP_PATH + "/config/zones.yml"

# load the YAML file containing named-admin configurations
begin
  CONFIG = YAML.load_file(options[:na_conf_file])
rescue
  puts "Error loading configuration file: " + $!
  exit
end

# read configuration options from the configuration file
options[:log_enable]     = CONFIG['log_enable']
options[:log_file]       = CONFIG['log_file']
options[:restart_cmd]    = CONFIG['restart_cmd']
options[:checkconf_path] = CONFIG['checkconf_path']


optparse = OptionParser.new do |opts|
  opts.banner = "Usage: named-admin COMMAND [argument] [options]"
  opts.program_name = "named-admin"
  opts.summary_width = 22
  opts.summary_indent = "  "
  opts.version = "1.1" 
  opts.separator ""
  opts.separator "List of Commands:"
  opts.separator "  find [zone-name] \t Find zone(s) by name, asterix [*] can by used as wildcard"
  opts.separator "  count \t\t Count zones"
  opts.separator "  add [zone-name] \t Add a zone to the zone file"
  opts.separator "  remove [zone-name] \t Remove a zone from the zone file"
  opts.separator "  print \t\t Print all zones (parsed, sorted)"
  opts.separator "  parse \t\t Parse all zones and write them back to the zone file (parsed, sorted)"
  opts.separator ""
  opts.separator "Options:"

  # Define the options, and what they do
  options[:named_conf_file] = CONFIG['named_zone_file']
  opts.on( '-f', '--file FILE', 'Path to your named zone configuration file' ) do |file|
    options[:named_conf_file] = file
  end

  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Output more information' ) do
    options[:verbose] = true
  end

  options[:check] = CONFIG['checkconf_enable']
  opts.on( '--[no-]check', 'Checks the configuration with named-checkconf after modifications (default: check)' ) do |check|
    options[:check] = check
  end

  options[:restart] = CONFIG['restart_enable']
  opts.on( '--[no-]restart', 'Option to restart named after zone manipulations (default: restart)' ) do |restart|
    options[:restart] = restart
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

begin
  optparse.parse!
rescue
   puts "Invalide option provided."
   puts optparse.help
  exit
end


begin
  # get the command to execute
  options[:run] = ARGV[0]
  options[:arg] = ARGV[1] 

  # for adding a new zone a zones template must exist
  if (options[:run] == "add") && !(File.exists?(options[:zone_tmpl_file]))
    puts "Please create a zone template file in order to insert zones."
    puts "An example can be found at config/zones.yml.dist"
    exit
  elsif !File.exists?(options[:zone_tmpl_file])
    zone_tmpl = {}
  else
    zone_tmpl = YAML.load_file(options[:zone_tmpl_file]) || {}
  end
 
  # create an NamedAdmin instance to handle the calls
  na = NamedAdmin.new(options[:named_conf_file],
                      zone_tmpl,
                      options[:log_file],
                      options[:log_enable],
                      options[:checkconf_path],
                      options[:restart_cmd],
                      options[:verbose]
                     )

  # indicator whether the zone file has been modified
  file_modifications = false

  # launch NamedAdmin with the option/parameters given
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
      puts "You should check your zone file with named-checkconf."
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
