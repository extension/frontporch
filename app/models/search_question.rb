# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE


class SearchQuestion < ActiveRecord::Base
  extend DataImportCommon
  
  # entrytypes
  FAQ = 1
  AAE = 2
  
  named_scope :faq_questions, {:conditions => {:entrytype => FAQ}}
  named_scope :aae_questions, {:conditions => {:entrytype => AAE}}

  named_scope :full_text_search, lambda{|options|
    match_string = options[:q]
    boolean_mode = options[:boolean_mode] || false
    if(boolean_mode)
      {:select => "#{self.table_name}.*, MATCH(content,fulltitle) AGAINST (#{sanitize(match_string)}) as match_score", :conditions => "MATCH(content,fulltitle) AGAINST (#{sanitize(match_string)} IN BOOLEAN MODE) AND status <> 'archived'"}
    else
      {:select => "#{self.table_name}.*, MATCH(content,fulltitle) AGAINST (#{sanitize(match_string)}) as match_score", :conditions => ["MATCH(content,fulltitle) AGAINST (?) AND status <> 'archived'", sanitize(match_string)]}
    end
  }
  
  
  def aae_question
    if self.entrytype == AAE
      return SubmittedQuestion.find_by_id(self.foreignid)
    else
      return nil    
    end
  end
  

  # -----------------------------------
  # Class-level methods
  # -----------------------------------
  class << self
    
    def retrieve_questions(questiontype,refreshall)
      # get the last time that we updated for this questiontype
      updatetime = UpdateTime.find_or_create(self,questiontype)    
      last_datasourced_at = updatetime.last_datasourced_at
      case questiontype
      when 'aae'
        timestampsql = self.aae_submittedquestions_timestamp_sql
        retrievesql = self.aae_submittedquestions_sql(last_datasourced_at,refreshall)
      when 'faq'
        retrievesql = self.faq_questions_sql(last_datasourced_at,refreshall)
      else
        return false
      end
      
      
      if(timestampsql.nil?)
        lastupdated = DateTime.now.utc
      else
        if(!(lastupdated = self.execute_timestamp_sql(timestampsql,"#{questiontype} search_questions")))
          return false
        elsif(!refreshall and !last_datasourced_at.nil?)
          if(lastupdated <= last_datasourced_at)
            return lastupdated
          end
        end
      end  

      logger.info "##################### Starting #{questiontype} search_questions retrieval..."
      # execute sql 
      begin
        self.connection.execute(retrievesql)
      rescue => err
        logger.error "ERROR: Exception raised during #{questiontype} search_questions retrieval: #{err}"
        return false
      end

      updatetime.update_attribute(:last_datasourced_at,lastupdated)
      logger.info "##################### Finished #{questiontype} search_questions retrieval."
      return lastupdated
    end
    
    def aae_submittedquestions_timestamp_sql
      aaetable = SubmittedQuestion.table_name
      timestampsql = "SELECT MAX(#{aaetable}.updated_at) as last_updated_time FROM #{aaetable}"
      return timestampsql
    end
    
    # TODO: change for multiple answers?
    def aae_submittedquestions_sql(last_datasourced_at=nil,refreshall=false)
        mytable = self.table_name        
        aaetable = SubmittedQuestion.table_name

        sql = "INSERT INTO #{mytable} (entrytype,foreignid,source,sourcewidget,displaytitle,fulltitle,content,status,created_at,updated_at)"
        sql +=  " SELECT #{SearchQuestion::AAE},#{aaetable}.id,#{aaetable}.external_app_id,#{aaetable}.widget_name,"
        sql += "SUBSTRING(#{aaetable}.asked_question,1,255),#{aaetable}.asked_question,#{aaetable}.current_response,"
        sql += "#{aaetable}.status,#{aaetable}.created_at,#{aaetable}.updated_at"
        sql +=  " FROM #{aaetable}"
        sql +=  " WHERE #{aaetable}.current_response IS NOT NULL"
        if(!refreshall and !last_datasourced_at.nil?)
          compare_time_string = last_datasourced_at.strftime("%Y-%m-%d %H:%M:%S")
          sql +=  " AND #{aaetable}.updated_at >= '#{compare_time_string}'"
        end
        sql +=  " ON DUPLICATE KEY UPDATE #{mytable}.updated_at = #{aaetable}.updated_at,"
        sql +=  "#{mytable}.status = #{aaetable}.status,"
        sql +=  "#{mytable}.source =#{aaetable}.external_app_id,"
        sql +=  "#{mytable}.sourcewidget = #{aaetable}.widget_name,"
        sql +=  "#{mytable}.displaytitle = SUBSTRING(#{aaetable}.asked_question,1,255), #{mytable}.fulltitle = #{aaetable}.asked_question, "
        sql +=  "#{mytable}.content = #{aaetable}.current_response"

      return sql
    end
  
    def faq_questions_sql(last_datasourced_at=nil,refreshall=false)
      mydatabase = self.connection.instance_variable_get("@config")[:database]
      faqtable = Page.table_name
      mytable = self.table_name        
      
        
      sql = "INSERT INTO #{mydatabase}.#{mytable} (entrytype,foreignid,displaytitle,fulltitle,content,created_at,updated_at)"
      sql +=  " SELECT #{SearchQuestion::FAQ},#{faqtable}.id,"
      sql += "CAST((SUBSTRING(#{faqtable}.title,1,255)) AS BINARY),CAST(#{faqtable}.title AS BINARY),CAST(#{faqtable}.content AS BINARY),"
      sql += "#{faqtable}.source_created_at,#{faqtable}.source_updated_at"
      sql +=  " FROM #{faqtable}"
      sql +=  " WHERE #{faqtable}.datatype = 'Faq'"
      if(!refreshall and !last_datasourced_at.nil?)
        compare_time_string = last_datasourced_at.strftime("%Y-%m-%d %H:%M:%S")
        sql +=  " AND #{faqtable}.source_updated_at >= '#{compare_time_string}'"
      end
      sql +=  " ON DUPLICATE KEY UPDATE #{mydatabase}.#{mytable}.updated_at = #{faqtable}.source_updated_at"
      sql +=  "#{mydatabase}.#{mytable}.displaytitle = CAST((SUBSTRING(#{faqdatabase}.revisions.question_text,1,255)) AS BINARY), #{mydatabase}.#{mytable}.fulltitle = CAST(#{faqdatabase}.revisions.question_text AS BINARY), "
      sql +=  "#{mydatabase}.#{mytable}.content = CAST(#{faqdatabase}.revisions.answer AS BINARY) "
  
      return sql
    end
  
  end
end