require APP_PATH + "/lib/NamedConf"

class NamedAdmin
  
  def initialize(file, zone_tmpl = {})
    @file = file
    @nc = NamedConf.new(@file)
    @zone_tmpl = zone_tmpl
  end
  
  def count_zones
    puts "Scanning #{@file}..."
    @nc.read
    puts "Number of zones found: #{@nc.zones.size}"
  end

  def search_zone(name = nil)
    name = get_args("Enter zone name:") unless name
    @nc.read
    if zone = @nc.find_zone(name)
      puts zone.print
    else
      puts "Zone #{name} not found."
    end
  end

  def insert_zone(name = nil)
    name = get_args("Please enter the name of the zone you want to insert:") unless name
    if @zone_tmpl.keys.length > 1
      template = get_args("Please select a zone template:\n#{list_zone_tmpl}", 2)
    else
      template = 0
    end
    zone = template_to_zone(template.to_i, name)
    @nc.read
    if @nc.insert_zone(name, zone)
      puts "Add zone #{name}:"
      write(@nc)
    else
      puts "Zone already exists."
    end
  end

  def delete_zone(name = nil)
    name = get_args("Please enter the name of the zone you want to delete:") unless name
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
    error = %x[#{CONFIG['named-checkconf']['path']} #{@file}]
    error.empty? ?
      puts("named-checkconf: syntax of #{@file} OK") :
      puts("named-checkconf: syntax error in #{@file}: \n#{error}")
  end

  private

  def write(nc)
    print "Write changes to #{@file} [y/N]: "
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
