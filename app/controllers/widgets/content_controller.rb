# === COPYRIGHT:
#  Copyright (c) 2005-2009 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class Widgets::ContentController < ApplicationController
  # default amount of data items
  DEFAULT_QUANTITY = 3
  # default width of the widget
  DEFAULT_WIDTH = 300
  
  # page with content widget builder
  def index
    @launched_categories = Category.root_categories.show_to_public.all(:order => 'name')
    @default_quantity = DEFAULT_QUANTITY
    @default_width = DEFAULT_WIDTH
    @widget_code = "<script type=\"text/javascript\" src=\"#{url_for :controller => 'widgets/content', :action => :show, :escape => false, :quantity => @default_quantity, :width => @default_width, :type => 'articles_faqs'}\"></script>"  
    render :layout => 'widgetshome'
  end
  
  # generate_new_widget builds the widget from a template (rather than doing a document.write as you see in the show method). 
  # this is because we have to replace the html for the widget div instead of return js to modify it, because that js is only 
  # executing on page load. that's why we do it with show is because that's called from the js as part of the hosting page's load
  def generate_new_widget
    # handle parameters and querying data for the widget
    setup_contents
    (!@content_tags or @content_tags == 'All') ? tags_to_filter = nil : tags_to_filter = @content_tags 
    @widget_code = "<script type=\"text/javascript\" src=\"#{url_for :controller => 'widgets/content', :action => :show, :escape => false, :tags => tags_to_filter, :quantity => @quantity, :width => @width, :type => @content_type, :tag_operator => @tag_operator}\"></script>"
    render :layout => false
  end
  
  def show
    # handle parameters and querying data for the widget
    setup_contents
    
    # return js to write the widget to the page when the page hosting the widget loads
    render :update do |page|         
      page << "document.write('#{escape_javascript(AppConfig.content_widget_styles)}');"
      page << "document.write('<div id=\"content_widget\" style=\"width:#{@width}px\"><h3><img src=\"http://#{request.host_with_port}/images/common/extension_icon_40x40.png\" /> <span>eXtension Latest #{@type}: #{@content_tags}</span><br class=\"clearing\" /></h3><ul>');"
      page << "document.write('<h3>There are currently no content items at this time.</h3>')" if @contents.length == 0
        
      @contents.each do |content| 
        case content.class.name 
        when "Faq" 
          page << "document.write('<li><a href=#{url_for :controller => '/faq', :action => :detail, :id => content.id, :only_path => false}>');"
          page << "document.write('#{escape_javascript(content.question)}');"  
        when "Article"
          page << "document.write('<li><a href=#{url_for :controller => '/articles', :action => :page, :id => content.id, :only_path => false}>');"
          page << "document.write('#{escape_javascript(content.title)}');"  
        when "Event"
          page << "document.write('<li><a href=#{url_for :controller => '/events', :action => :detail, :id => content.id, :only_path => false}>');"

          page << "document.write('#{escape_javascript(content.title)}');" 
        else
          next
        end
        page << "document.write('</a></li>');"
      end
      page << "document.write('</ul>');" 
      page << "document.write('<p><a href=\"http://#{request.host_with_port}/widgets/content\">Create your own eXtension widget</a></p></div>');" 
    end
  end
  
  # for testing purposes only
  def test_widget
    render :layout => false
  end
  
  private
  
  # setup from parameters, set instance variables and query db for widget data
  # some duplicated code in here, may have to revisit this
  def setup_contents
    params[:tags].blank? ? (content_tags = nil) : (content_tags = params[:tags])  
    
    # if width is blank or zero or width.to_i is zero (possible non-integer), then default
    params[:width].blank? ? @width = DEFAULT_WIDTH : @width = params[:width].to_i
    @width = DEFAULT_WIDTH if @width == 0
    
    # if quantity is blank or zero or quantity.to_i is zero (possible non-integer), then default
    params[:quantity].blank? ? @quantity = DEFAULT_QUANTITY : @quantity = params[:quantity].to_i
    @quantity = DEFAULT_QUANTITY if @quantity == 0
    
    params[:type].blank? ? @content_type = "faqs_articles" : @content_type = params[:type]
    
    if content_tags.nil?
      @content_tags = 'All'
      @tag_operator = nil
    else
      tags_to_query = Tag.castlist_to_array(content_tags,false,false) 
      @content_tags = tags_to_query.join(', ')
      # operator to instruct whether to pull content tagged with ALL the tags or ANY of the tags
      params[:tag_operator].blank? ? @tag_operator = "or" : @tag_operator = params[:tag_operator] 
    end
    
    case @content_type
    when 'faqs'
      @type = 'FAQs'
      if content_tags
        @contents = Page.main_recent_faq_list(:content_tags => content_tags, :limit => @quantity, :tag_operator => @tag_operator)
      else
        @contents = Page.main_recent_faq_list(:limit => @quantity)
      end
    when 'articles'
      @type = 'Articles'
      if content_tags
        @contents = Page.main_recent_list(:content_tags => content_tags, :limit => @quantity, :tag_operator => @tag_operator)
      else
        @contents = Page.main_recent_list(:limit => @quantity)
      end
    when 'events'
      @type = 'Events'
      if content_tags
        @contents = Page.main_recent_event_list({:calendar_date => Time.now.to_date, :limit => @quantity, :content_tags => content_tags, :tag_operator => @tag_operator})
      else
        @contents = Page.main_recent_event_list({:calendar_date => Time.now.to_date, :limit => @quantity})
      end
    # if the type is articles and faqs or if it's anything else, default to articles and faqs
    else
      @type = 'Articles and FAQs'
      if content_tags
        faqs = Page.main_recent_faq_list(:content_tags => content_tags, :limit => @quantity, :tag_operator => @tag_operator)
        articles = Page.main_recent_list(:content_tags => content_tags, :limit => @quantity, :tag_operator => @tag_operator)
      else
        faqs = Page.main_recent_faq_list(:limit => @quantity)
        articles = Page.main_recent_list(:limit => @quantity)
      end
      @contents = content_date_sort(articles, faqs, @quantity)
    end
  end

end
