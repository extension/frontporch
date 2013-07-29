#!/usr/bin/env ruby
require 'rubygems'
require 'thor'
require 'lockfile'
require 'thread'


class Checklinks < Thor
  include Thor::Actions

  MAX_THREADS = 5

  # these are not the tasks that you seek
  no_tasks do
    # load rails based on environment
    
    def load_rails(environment)
      if !ENV["RAILS_ENV"] || ENV["RAILS_ENV"] == ""
        ENV["RAILS_ENV"] = environment
      end
      require_relative("../config/environment")
    end

    def queue_and_process_links(verbose = false)
      thread_pool = []
      # put content links into a thread safe queue
      check_count = Link.checklist.count
      
      linkqueue = Queue.new
      
      # get all unchecked external and local links
      Link.checklist.unchecked.all.each do |link|
        linkqueue << link
      end
      
      # check all warning links from yesterday or earlier
      Link.checklist.warning.checked_yesterday_or_earlier.all.each do |link|
        linkqueue << link
      end
      
      # check all broken links from yesterday or earlier
      # if over MAX_ERROR_COUNT, it's just going to return
      Link.checklist.broken.checked_yesterday_or_earlier.all.each do |link|
        linkqueue << link
      end
      
      # check up to total count / 29 to give us a rolling check
      daily_check_limit = (check_count / 29)
      Link.checklist.checked_over_one_month_ago.all.each do |link|
        linkqueue << link
      end
          

      # fill up our thread pool
      
      while thread_pool.size <= MAX_THREADS
        # create the thread
        thread_pool << Thread.start {
          # thread work
          while true
            sleep(0.1) # if a thread goes idle, sleep for a moment so it doesn't stay on the cpu
            if linkqueue.length > 0            
              link = linkqueue.pop          
              link.check_url
              if(verbose)
                puts "Processed #{link.url} Response: #{link.last_check_response? ? link.last_check_code : 'no response'}"
              end
            end
          end  
        }
      end
      
      # wait on the threads to finish
      while linkqueue.length > 0
        sleep(1)
      end
    end
  end

  desc "go", "Check the Links that need to be checked"
  method_option :environment,:default => 'production', :aliases => "-e", :desc => "Rails environment"
  method_option :verbose,:default => false, :aliases => "-v", :desc => "Verbose output"
  def go
    load_rails(options[:environment])
    begin
      Lockfile.new('/tmp/checklinks.lock', :retries => 0) do
        queue_and_process_links(options[:verbose])
        Page.update_broken_flags
        LinkStat.update_counts
      end
    rescue Lockfile::MaxTriesLockError => e
      puts "Another link checker is already running. Exiting."
    end
  end
end

Checklinks.start


