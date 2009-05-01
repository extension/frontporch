# === COPYRIGHT:
#  Copyright (c) 2005-2006 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class FaqController < DataController
  
  def index
    set_title('Answered Questions from Our Experts', "Frequently asked questions from our resource area experts.")
    set_titletag('Answered Questions from Our Experts - eXtension')
    return do_404 unless Faq.orderings.has_value?(params[:order])
    @faqs = Faq.categorized(@category.name).ordered(params[:order]).paginate(:page => params[:page])
    @youth = true if @topic and @topic.name == 'Youth'
    render :partial => 'data/index', :locals => { :items => @faqs, :klass => Faq }, :layout => true
  end
  
  def detail
    @right_sidebar_to_display = 'faq_navigation'
    @faq = Faq.find_by_id(params[:id])
    if @faq
      set_title("#{@faq.question}", "Frequently asked questions from our resource area experts.")
      set_titletag("#{@faq.question} - eXtension")
      @published_content = true
      
      if @faq.reference_questions    
        @refq = @faq.reference_questions.split(',') 
      end
    else 
      @missing = "FAQ #{params[:id]}"
      do_404
      return
    end
    
    for tag in @faq.tags
      category = tag if !tag.community.nil?
      @youth = true if tag.name == 'youth'
    end
    
    # go through tags, get first one that has .community not nil
    if category
      @community = category.community
      @homage = Article.categorized(['homage', category.name]).ordered.first if @community
      @in_this_section = Article.categorized(['contents', category.name]).ordered.first if @community
      @youth = true if @community and @community.topic and @community.topic.name == 'Youth'
    end
    
    @community_tags = @faq.tags.community
    adtag = @community_tags[0] if @community_tags and @community_tags.length > 0
    @sponsors = Advertisement.prioritized_for_tag(adtag) if adtag
    flash.now[:googleanalytics] = request.request_uri + "?" + @community_tags.collect{|tag| tag.community }.uniq.compact.collect { |community| community.category }.join('+').gsub(' ','_') if @community_tags and @community_tags.length > 0
  end
  
  #feed for questions asked via the ask an expert tool to be consumed by the faq application
  def send_questions
    @submitted_questions = ExpertQuestion.find(:all, :conditions => ["status = 'submitted' and expert_questions.updated_at >= ?", time_in_params])    
    headers["Content-Type"] = "application/xml"
    render :template => 'faq/expert_questions', :layout => false
  end
  
  private
  def time_in_params
    Time.utc(params['year'], params['month'], params['day'], params['hour'], params['minute'], params['second'])
  end
end
