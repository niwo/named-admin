require "yaml"
require "lib/NamedConf"

ZONE_TMPL = YAML.load_file( 'config/zones.yml' )

class NamedAdmin
  
  def initialize(file)
    @file = file
    @nc = NamedConf.new(@file)
  end
  
  def self.usage
    puts "Usage:"
    puts "Search a zone by name:\t named-admin -s | --search-zone [zone name]"
    puts "Insert a zone by name:\t named-admin -i | --insert-zone [zone name]"
    puts "Delete a zone by name:\t named-admin -d | --delete-zone [zone name]"
    puts "Print (parsed, sorted):\t named-admin -p | --print"
    puts "Write (parsed, sorted):\t named-admin -w | --write"
    puts "Count number of zones:\t named-admin -c | --count--zones"
    exit
  end

  def count_zones
    puts "Scanning #{@file}..."
    @nc.read
    puts "Number of zones found: #{@nc.zones.size}"
  end

  def search_zone
    name = get_args("Enter zone name:")
    @nc.read
    if zone = @nc.find_zone(name)
      puts zone.print
    else
      puts "Zone #{name} not found."
    end
  end

  def insert_zone
    name = get_args("Please enter the name of the zone you want to insert:")
    if ZONE_TMPL.keys.length > 1
      template = get_args("Please select a zone template:\n#{list_zone_tmpl}", 2)
    else
      template = 0
    end
    zone = template_to_zone(template.to_i, name)
    @nc.read
    if @nc.insert_zone(name, zone)
      puts "Add zone #{name}:"
      write(@nc)
      # check file syntax with named-checkconf if enbled
      if CONFIG['named-checkconf']['enable'] || false
        named_checkconf
      end 
    else
      puts "Zone already exists."
    end
  end

  def delete_zone
    name = get_args("Please enter the name of the zone you want to delete:")
    @nc.read
    @nc.sort_zones
    if @nc.delete_zone(name)
      puts "Delete zone #{name}"
      write(@nc)
    else
      puts "Zone #{name} not found."
    end
  end

  def parse
    @nc.read
    @nc.sort_zones
    puts "file parsed and sorted."
    write(@nc)
  end

  def print_file
    @nc.read
    puts @nc.print
  end
  
  def named_checkconf
    error = %x["#{CONFIG['named-checkconf']['path']} #{CONFIG['named.conf']['path']}"]
    error.empty? ? 
      puts("named-checkconf: syntax of #{@file} OK") :
      puts("named-checkconf: syntax error in #{@file}: \n#{error}")
  end

  private

  def write(nc)
    puts "Write changes to #{@file}?"
    print "(y/n) "
    if $stdin.gets.chomp == 'y'
      begin 
        nc.write
      rescue => message 
        puts message
        exit
      end
      puts "Succesfully written."
    else
      puts "Exit without write."
    end
  end

  def get_args(text, arg = 1)
    if ARGV[arg]
      return ARGV[arg]
    else
      puts text
      return $stdin.gets.chomp!
    end
  end

  def list_zone_tmpl
    n = 1
    list = ""
    ZONE_TMPL.keys.sort.each do |zone_key|
      list << "#{n}: #{zone_key}\n"
      n = n + 1
    end
    list
  end
  
  def template_to_zone(index, zone_name)
    template = ZONE_TMPL[ZONE_TMPL.keys[index - 1]]
    zone = []
    template.each_pair {|key,value| zone << {key => value.sub('{{name}}', zone_name)} }
    zone
  end
end
