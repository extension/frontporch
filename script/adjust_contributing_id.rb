#!/usr/bin/env ruby
require 'getoptlong'

### Program Options
progopts = GetoptLong.new(
  [ "--environment","-e", GetoptLong::OPTIONAL_ARGUMENT ]
)

@environment = 'production'

progopts.each do |option, arg|
  case option
    when '--environment'
      @environment = arg
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



def update_from_submitted_question_events(connection)
  
  ActiveRecord::Base::logger.info "##################### Starting fixing legacy submitted questions that used a contributing_question_id directly instead of a foreignid referenced through the id of search_questions...."
  
  #General Purpose for this script: for each submitted question resolved before 8/12/2009, the
   # place to look for the search_questions id is to find the foreign id equal to the old current_contributing_question field.
   #Then put the resulting search_questions id in the current_contributing_question field of the submitted_question and appropriate response contributing_question_ids. 
 
   sqlist = SubmittedQuestion.find(:all, :conditions => "resolved_at < '2009-08-12' and current_contributing_question IS NOT NULL",:order => " submitted_questions.id")
  
  
   sqlist.each do |sq|
  
      searched_question = SearchQuestion.find_by_foreignid_and_entrytype(sq.current_contributing_question, SearchQuestion::FAQ)   
      puts "sqid= " + sq.id.to_s
      if searched_question
        puts "updating submitted_questions #{sq.id} with id of searched_question= #{searched_question.id}, old contributing_question= #{sq.current_contributing_question}"
       
       sq.update_attribute(:current_contributing_question, searched_question.id)
          # find responses and correct contributing question_id
          response= sq.responses.find(:first, :conditions => "contributing_question_id IS NOT NULL", :order => "created_at DESC") 
          if response  
            puts "updating response id=#{response.id} contributing_question_id from #{response.contributing_question_id} to #{searched_question.id}"
            response.update_attribute(:contributing_question_id, searched_question.id)
          end
          
        # now find the submitted_question_event referencing this contributing_question_id and change it
        sqevent = sq.submitted_question_events.find(:first, :conditions => "contributing_question IS NOT NULL", :order => "created_at DESC")
        if sqevent
          puts "updating submitted_question_events id=#{sqevent.id} contributing_question_id from #{sqevent.contributing_question} to #{searched_question.id}"
          sqevent.update_attribute(:contributing_question, searched_question.id)
        end
      end
        
     
   end
 
  
  
  ActiveRecord::Base::logger.info "####Finished fixing legacy submitted questions that used a contributing_question_id directly instead of a foreignid referenced through the id of search_questions.######"
  return true
end

#################################
# Main

# go!
result = update_from_submitted_question_events(SubmittedQuestionEvent.connection)

