#!/usr/bin/env ruby
# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

require 'getoptlong'

### Program Options
progopts = GetoptLong.new(
  [ "--environment","-e", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--forceupdate","-f", GetoptLong::NO_ARGUMENT]
)

@environment = 'production'
@forceupdate = false

progopts.each do |option, arg|
  case option
    when '--environment'
      @environment = arg
    when '--forceupdate'
      @forceupdate = true
    else
      puts "Unrecognized option #{opt}"
      exit 0
    end
end
### END Program Options

if !ENV["RAILS_ENV"] || ENV["RAILS_ENV"] == ""
  ENV["RAILS_ENV"] = @environment
end

require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

if @forceupdate
  #loop through all the managed lists and force the memberships to be updated
  List.managed.all.each do |list|
    puts "Forcefully updating mailman information for: #{list.name}"
    result = list.create_or_update_mailman_list(true)
    puts "#{list.name} adds: #{result[:add_count]} removes: #{result[:remove_count]}"
  end
else
  # loop through all the lists that need updating
  List.needs_mailman_update.managed.all.each do |list|
    puts "Updating mailman information for: #{list.name}"
    result = list.create_or_update_mailman_list
    puts "#{list.name} adds: #{result[:add_count]} removes: #{result[:remove_count]}"
  end
end

