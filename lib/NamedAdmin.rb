#!/usr/bin/env ruby

require "logger"
require "lib/NamedConf"

class NamedAdmin
  def initialize(file,
                 zone_tmpl,
                 log_file,
                 log_enable  = true,
                 chk_path    = "/usr/sbin/named-checkconf",
                 restart_cmd = "service named restart",
                 verbose     = false
                )
    @file = file
    @nc = NamedConf.new(@file)
    @zone_tmpl = zone_tmpl
    @log_enable = log_enable
    @log_file = log_file
    @chk_path = chk_path
    @restart_cmd = restart_cmd
    @verbose = verbose
    if @log_enable
      log_file ||= File.expand_path(File.dirname(__FILE__) + "/../log/named-admin.log")
      log = File.open(log_file, File::WRONLY | File::APPEND | File::CREAT)
      @log = Logger.new(log, 10, 1024000)
    end
  end

  # handle Control-C nicely
  trap("INT") do 
    puts
    STDERR.puts "received Control-C: exit"
    exit
  end
  
  def count_zones
    puts "Scanning #{@file}..." if @verbose
    @nc.read
    puts "Number of zones found: #{@nc.zones.size}"
  end

  def find_zones(name = nil)
    name = get_args("Enter zone name: ") unless name
    @nc.read
    zones = @nc.find_zones(name)
    unless zones.empty?
      puts "Find for \"#{name}\" found #{zones.size} zone#{'s' if zones.size > 1}:"
      zones.each do |zone|
        @verbose ? puts(zone.print) : puts(zone.name)
      end
      return true
    else
      puts "No zone found named \"#{name}\"."
      return false
    end
  end

  def add_zone(name = nil)
    # load the zones
    @nc.read

    # ask for the zone name if not provided
    name = get_args("Please enter the name of the zone you want to insert.\nzone-name: ") unless name

    # make sure the zone doesn't already exist
    if @nc.zone_exists?(name)
      puts "Abort: zone #{name} already exists."
      exit
    end
    
    # check if the zone name is valid
    if check_zone_name(name)
      puts("#{name} seems to be a valid domain name.") if @verbose
    else
      puts("Warning: #{name} seems NOT to be a valid domain name!")
      exit unless get_args("Do you really want to continue? [y/N]: ") == "y" 
    end

    # if there is more then one zone in the template, present the menu
    if @zone_tmpl.keys.length > 1
      template = (get_args("Please select a zone template:\n#{list_zone_tmpl}", true).to_i - 1)
    else
      template = 0
    end
    
    # parse the zone using the template
    zone = template_to_zone(template.to_i, name)

    # insert the zone and ask wether it should be written to the zone file
    if @nc.add_zone(name, zone)
      puts "Added zone #{name}:"
      puts @nc.get_zone_by_name(name).print
      return write(@nc, "add zone", name)
    else
      puts "Error adding zone #{name}."
      return false
    end
  end

  def remove_zone(name = nil)
    # ask for the zone name if not provided
    name = get_args("Please enter the name of the zone you want to delete\nzone-name: ") unless name
    
    # load the zones
    @nc.read
    
    # remove the zone and ask wether it should be written to the zone file
    if @nc.remove_zone(name)
      puts "Removed zone #{name}."
      return write(@nc, "remove zone", name)
    else
      puts "Zone #{name} not found."
      return false
    end
  end

  def parse
    @nc.read
    @nc.sort_zones
    puts "File parsed and sorted."
    write(@nc)
  end
 
  def check_zone_name(name)
    (name =~ /^[-A-Z0-9.]+$/i) != nil
  end

  def print_file
    @nc.read
    puts @nc.print
  end
  
  def named_checkconf
    error = %x[#{@chk_path} #{@file}]
    if error.empty?
      puts("named-checkconf: syntax of #{@file} OK")
      return true
    else
      puts("named-checkconf: syntax error in #{@file}: \n#{error}")
      return false
    end
  end

  def named_restart(confirm = true)
    answer = get_args("Do you want to restart named \"#{@restart_cmd}\" ? [y/N]: ") if confirm
    if confirm && (answer != "y")
      return false
    end
    system("#{@restart_cmd} 2>&1")
  end

  private

  def write(nc, action, zone)
    if get_args("Write changes to #{@file} [y/N]: ") == "y"
      begin 
        nc.write
        info = "Action: #{action}, Zone: #{zone}, File: #{@file}: "
      rescue => error
        puts error
        @log.fatal(info + error) if @log_enable
        exit
      end
      puts "Succesfully written."
      @log.info(info + "modification successfully written") if @log_enable
      return true
    else
      puts "Exit without write."
      return false
    end
  end
  
  def get_args(text, newline = false)
    newline ? puts(text) : print(text)
    return $stdin.gets.chomp!
  end

  def list_zone_tmpl
    n = 1
    list = ""
    @zone_tmpl.keys.sort.each do |zone_key|
      list << "#{n}: #{zone_key}\n"
      n = n + 1
    end
    list
  end
  
  def template_to_zone(index, zone_name)
    template = @zone_tmpl[@zone_tmpl.keys[index - 1]]
    zone = []
    template.each_pair {|key,value| zone << {key => value.sub('{{name}}', zone_name)} }
    zone
  end
end
