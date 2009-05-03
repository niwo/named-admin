#!/usr/bin/env ruby

#
# named-admin Copyright (C) 2008 Nik Wolfgramm, licesnsed under GPL
#
# = named-admin.rb: command line tool for bind named.conf zone administration
# Reads, writes and sorts the file and finds, inserts, deletes and counts zones
#

# makes sure the class definition files is found
$: << File.expand_path(File.dirname(__FILE__) + '/../lib')
require "lib/NamedAdmin"

# test if any arguments are passed
if ARGV.length < 1
  NamedAdmin.usage
end

CONFIG = YAML.load_file( 'config/config.yml' )
FILE = CONFIG['named.conf']['path']

na = NamedAdmin.new(FILE)

# capture arguments
case ARGV[0]
when '-c', '--count-zones'
  na.count_zones
when '-s', '--search-zone'
  na.search_zone
when '-i', '--insert-zone'
  na.insert_zone
when '-d', '--delete-zone'
  na.delete_zone
when '-p', '--print'
  na.print_file
when '-w', '--write'
  na.parse
when '--check'
  na.named_checkconf
else
  NamedAdmin.usage
end