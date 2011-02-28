# === COPYRIGHT:
#  Copyright (c) 2005-2011 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class PagesController < ApplicationController
  layout 'pubsite'
  before_filter :set_content_tag_and_community_and_topic
  before_filter :login_optional
  
  
  def redirect_article
    # folks chop off the page name and expect the url to give them something
    if not (params[:title] or params[:id])
      redirect_to site_articles_url(with_content_tag?), :status=>301
      return
    end
    
    # get the title out, find it, and redirect  
    if params[:title]
      title_to_lookup = CGI.unescape(request.request_uri.gsub('/pages/', ''))
      # comes in double-escaped from apache to handle the infamous '?'
      title_to_lookup = CGI.unescape(title_to_lookup)
      # why is this?
      title_to_lookup = title_to_lookup.gsub('??.html', '?')
      
      # special handling for mediawiki-like "Categoy:bob" - style titles
      if title_to_lookup =~ /Category\:(.+)/
        content_tag = $1.gsub(/_/, ' ')
        redirect_to content_tag_index_url(:content_tag => content_tag), :status=>301
        return
      end
      
      if title_to_lookup =~ /\/print(\/)?$/
        print = true
        title_to_lookup.gsub!(/\/print(\/)?$/, '')
      end
      
      @page = Page.find_by_title_url(title_to_lookup)       
    elsif(params[:id])
      if(params[:print])
        print = true
      end
      @page = Page.find_by_id(params[:id])
    end
    
    if @page
      if(print)
        redirect_to(print_page_url(:id => @page.id, :title => @page.url_title), :status => :moved_permanently)
      else
        redirect_to(page_url(:id => @page.id, :title => @page.url_title), :status => :moved_permanently)
      end
    else
      @missing = title_to_lookup
      do_404
      return
    end
  end
  
  def redirect_faq
    # folks chop off the page name and expect the url to give them something
    if (!params[:id])
      redirect_to site_articles_url(with_content_tag?), :status=>301
      return
    end
    if(params[:print])
      print = true
    end
    @page = Page.faqs.find_by_migrated_id(params[:id])
    if @page
      if(print)
        redirect_to(print_page_url(:id => @page.id, :title => @page.url_title), :status => :moved_permanently)
      else
        redirect_to(page_url(:id => @page.id, :title => @page.url_title), :status => :moved_permanently)
      end
    else
      return do_404
    end
  end
  
  def redirect_event
    # folks chop off the page name and expect the url to give them something
    if (!params[:id])
      redirect_to site_articles_url(with_content_tag?), :status=>301
      return
    end
    if(params[:print])
      print = true
    end
    @page = Page.events.find_by_migrated_id(params[:id])
    if @page
      if(print)
        redirect_to(print_page_url(:id => @page.id, :title => @page.url_title), :status => :moved_permanently)
      else
        redirect_to(page_url(:id => @page.id, :title => @page.url_title), :status => :moved_permanently)
      end
    else
      return do_404
    end    
  end
  
  
    
  def show
    # folks chop off the page name and expect the url to give them something
    if (!params[:id])
      redirect_to site_articles_url(with_content_tag?), :status=>301
      return
    end
    
    @page = Page.find_by_id(params[:id])
    if @page
      @published_content = true
    else
      return do_404
    end

    if(@page.is_event?)
      (@selected_time_zone = (!@currentuser.nil? and @currentuser.has_time_zone?) ? @currentuser.time_zone : @page.time_zone) if @page.time_zone
    end
    
    # redirect check
    if(!params[:title] or params[:title] != @page.url_title)
      redirect_to(page_url(:id => @page.id, :title => @page.url_title),:status => :moved_permanently)
    end

    # get the tags on this article that correspond to community content tags
    @page_content_tags = @page.tags.content_tags.reject{|t| Tag::CONTENTBLACKLIST.include?(t.name) }.compact
    @page_content_tag_names = @page_content_tags.map(&:name)
    @page_bucket_names = @page.content_buckets.map(&:name)
        
    if(!@page_content_tags.blank?)
      # is this article tagged with youth?
      @youth = true if @page_bucket_names.include?('youth')
      
      # news check to set the meta tags for noindex
      @published_content = false if (@page_bucket_names.include?('news') and !@page_bucket_names.include?('originalnews'))
      
      # noindex check to set the meta tags for noindex
      @published_content = false if @page_bucket_names.include?('noindex')
      
      # get the tags on this article that are content tags on communities
      @community_content_tags = (Tag.community_content_tags & @page_content_tags)
    
      if(!@community_content_tags.blank?)
        @sponsors = Sponsor.tagged_with_any_content_tags(@community_content_tags.map(&:name)).prioritized
        # loop through the list, and see if one of these matches my @community already
        # if so, use that, else, just use the first in the list
        use_content_tag = @community_content_tags.rand
        @community_content_tags.each do |community_content_tag|
          if(community_content_tag.content_community == @community)
            use_content_tag = community_content_tag
          end
        end
      
        @community = use_content_tag.content_community
        @in_this_section = Page.contents_for_content_tag({:content_tag => use_content_tag})  if @community
        @youth = true if @community and @community.topic and @community.topic.name == 'Youth'
      end
    end
    
    if(@page.is_news?)
      set_title("#{@page.title} - eXtension News", "Check out the news from the land grant university in your area.")
      set_titletag("#{@page.title} - eXtension News")
    elsif(@page.is_faq?)
      set_title("#{@page.title}", "Frequently asked questions from our resource area experts.")
      set_titletag("#{@page.title} - eXtension")
    elsif(@page.is_event?)
      set_title("#{@page.title.titleize} - eXtension Event",  @page.title.titleize)
      set_titletag("#{@page.title.titleize} - eXtension Event")
    elsif @page_bucket_names.include?('learning lessons')
      set_title('Learning', "Don't just read. Learn.")
      set_titletag("#{@page.title} - eXtension Learning Lessons")
    else
      set_title("#{@page.title} - eXtension", "Articles from our resource area experts.")
      set_titletag("#{@page.title} - eXtension")
    end

    if @community_content_tags and @community_content_tags.length > 0
      flash.now[:googleanalytics] = request.request_uri + "?" + @community_content_tags.collect{|tag| tag.content_community }.uniq.compact.collect { |community| community.primary_content_tag_name }.join('+').gsub(' ','_') 
      flash.now[:googleanalyticsresourcearea] = @community_content_tags.collect{|tag| tag.content_community }.uniq.compact.collect { |community| community.primary_content_tag_name }.first.gsub(' ','_')
    end
    
  end
    
  def articles
    # validate order
    return do_404 unless Page.orderings.has_value?(params[:order])
    
    set_title('Articles', "Don't just read. Learn.")
    if(!@content_tag.nil?)
      set_title("All articles tagged with \"#{@content_tag.name}\"", "Don't just read. Learn.")
      set_titletag("Articles - #{@content_tag.name} - eXtension")
      pages = Page.articles.tagged_with_content_tag(@content_tag.name).ordered(params[:order]).paginate(:page => params[:page])
    else
      set_titletag("Articles - all - eXtension")
      pages = Page.articles.ordered(params[:order]).paginate(:page => params[:page])
    end
    @youth = true if @topic and @topic.name == 'Youth'
    render :partial => 'shared/dataitems', :locals => { :items => pages }, :layout => true
  end
  
  def news
    # validate order
    return do_404 unless Page.orderings.has_value?(params[:order])
    set_title('News', "Check out the news from the land grant university in your area.")
    if(!@content_tag.nil?)
      set_titletag("News - #{@content_tag.name} - eXtension")
      pages = Page.news.tagged_with_content_tag(@content_tag.name).ordered(params[:order]).paginate(:page => params[:page])
    else
      set_titletag("News - all - eXtension")
      pages = Page.news.ordered(params[:order]).paginate(:page => params[:page])
    end    
    @youth = true if @topic and @topic.name == 'Youth'
    render :partial => 'shared/dataitems', :locals => { :items => pages }, :layout => true
  end
  
  def learning_lessons
    # validate order
    return do_404 unless Page.orderings.has_value?(params[:order])
    set_title('Learning Lessons', "Don't just read. Learn.")
    set_titletag('Learning Lessons - eXtension')
    if(!@content_tag.nil?)
      set_titletag("Learning Lessons - #{@content_tag.name} - eXtension")
      pages = Page.articles.bucketed_as('learning lessons').tagged_with_content_tag(@content_tag.name).ordered(params[:order]).paginate(:page => params[:page])
    else
      set_titletag("Learning Lessons - all - eXtension")
      pages = Page.articles.bucketed_as('learning lessons').ordered(params[:order]).paginate(:page => params[:page])
    end    
    @youth = true if @topic and @topic.name == 'Youth'
    render :partial => 'shared/dataitems', :locals => { :items => pages }, :layout => true
  end
  
  def faqs
    # validate ordering
    return do_404 unless Page.orderings.has_value?(params[:order])
    set_title('Answered Questions from Our Experts', "Frequently asked questions from our resource area experts.")
    if(!@content_tag.nil?)
      set_title("Questions tagged with \"#{@content_tag.name}\"", "Frequently asked questions from our resource area experts.")
      set_titletag("Answered Questions from Our Experts - #{@content_tag.name} - eXtension")      
      pages = Page.faqs.tagged_with_content_tag(@content_tag.name).ordered(params[:order]).paginate(:page => params[:page])
    else
      set_titletag('Answered Questions from Our Experts - all - eXtension')
      pages = Page.faqs.ordered(params[:order]).paginate(:page => params[:page])
    end  
    @youth = true if @topic and @topic.name == 'Youth'
    render :partial => 'shared/dataitems', :locals => { :items => pages }, :layout => true
  end
  
  
  def events    
    set_title('Calendar', 'Check out our calendar to see what exciting events might be happening in your neighborhood.')
    if(!@content_tag.nil?)
      set_titletag("eXtension - #{@content_tag.name} - Calendar of Events")
      @eventslist  =  Page.events.monthly(get_calendar_month).ordered.in_states(params[:state]).tagged_with_content_tag(@content_tag.name)      
    else
      set_titletag('eXtension - all - Calendar of Events')
      @eventslist  =  Page.events.monthly(get_calendar_month).ordered.in_states(params[:state]).all
    end    
    @youth = true if @topic and @topic.name == 'Youth'
    render :action => 'events'    
  end
  
  def update_time_zone
    if request.post? and !params[:new_time_zone].blank? and !params[:id].blank? and event = Page.find_by_id(params[:id])
      # we need to do a timezone conversion here, take the time from the event and convert to the desired time zone
      time_obj = event.event_start.in_time_zone(params[:new_time_zone])
      render :update do |page|
        page.replace_html :time_with_tz, :partial => 'event_time', :locals => {:event_time => time_obj}
        page.visual_effect :highlight, :time_with_tz 
      end
    else
      do_404
      return
    end
  end
  
end