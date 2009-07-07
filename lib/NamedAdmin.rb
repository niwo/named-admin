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

  def find_zones(name = nil)
    name = get_args("Enter zone name: ") unless name
    @nc.read
    zones = @nc.find_zones(name)
    unless zones.empty? 
      zones.each { |zone| puts zone.print }
    else
      puts "No zone found named \"#{name}\"."
    end
  end

  def add_zone(name = nil)
    @nc.read
    name = get_args("Please enter the name of the zone you want to insert: ") unless name
    if @nc.zone_exists?(name)
      puts "Abort: zone #{name} already exists."
      exit
    end
    if @zone_tmpl.keys.length > 1
      template = (get_args("Please select a zone template:\n#{list_zone_tmpl}", 2).to_i - 1)
    else
      template = 0
    end
    zone = template_to_zone(template.to_i, name)
    if @nc.add_zone(name, zone)
      puts "Added zone #{name}:"
      puts @nc.get_zone_by_name(name).print
      write(@nc)
    else
      puts "Error adding zone #{name}."
    end
  end

  def remove_zone(name = nil)
    name = get_args("Please enter the name of the zone you want to delete:") unless name
    @nc.read
    @nc.sort_zones
    if @nc.remove_zone(name)
      puts "Removed zone #{name}."
      write(@nc)
    else
      puts "Zone #{name} not found."
    end
  end

  def parse
    @nc.read
    @nc.sort_zones
    puts "File parsed and sorted."
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

  def bind_restart
    puts %x[#{CONFIG['named-admin']['bind-restart-cmd']}]
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
