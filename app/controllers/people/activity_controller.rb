# === COPYRIGHT:
#  Copyright (c) 2005-2008 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class People::ActivityController < ApplicationController
  layout 'people'
  before_filter :login_required
  before_filter :check_purgatory
  
  def index
  end
  
  def show
    begin
      @activity = Activity.find(params[:id])
    rescue ActiveRecord::RecordNotFound  
      flash[:error] = 'That activity does not exist'  
      return(redirect_to(:action => 'index'))
    end
    
    if(@activity.privacy == Activity::PRIVATE)
      flash[:error] = 'The specified activity entry is private.'  
      return(redirect_to(:action => 'index'))
    end    
  end
  
  def showuser
    begin
      @showuser = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound  
      flash[:error] = 'That user does not exist'  
      return(redirect_to(:action => 'index'))
    end      
    @filteredparameters = FilterParams.new(params)


    @activitylist = @showuser.activities.displayactivity.paginate(:all, :order => 'created_at DESC', :page => params[:page])
    @page_title = "Activity for #{@showuser.fullname}"
    feedtitle = "#{@showuser.fullname} Activity Atom Feed"

    urlparams = @filteredparameters.option_values_hash.merge({:id => @showuser.id, :feedkey => @currentuser.feedkey})
    urlparams.delete(:dateinterval)
    urlparams.delete(:datefield)
    urlparams.merge!({:controller => '/people/feeds', :action => :showuser})
    @feedurl = url_for(urlparams)
    @feedlink = "<link rel='alternate' type='application/atom+xml' href='#{@feedurl}', title='#{feedtitle}' />"
    respond_to do |format|
      format.html # show.html.erb
    end
    
  end
  
  def communities
    @filteredparams = FilterParams.new(params)
    @filteredparams.order=@filteredparams.order('name')
    @findoptions = @filteredparams.findoptions
    
    @displayfilter = @filteredparams.communitytype.nil? ? 'all' : @filteredparams.communitytype
    @activitydisplay = @filteredparams.activitydisplay.nil? ? 'communityconnection' : @filteredparams.activitydisplay
    
    # doesn't yet accept a filtered listing
    case @displayfilter
    when 'approved'
      @approved_communities = Community.find_all_by_entrytype(Community::APPROVED,@filteredparams.order) 
    when 'usercontributed'
      @usercontributed_communities = Community.find_all_by_entrytype(Community::USERCONTRIBUTED, @filteredparams.order) 
    else
      @approved_communities = Community.find_all_by_entrytype(Community::APPROVED, @filteredparams.order) 
      @usercontributed_communities = Community.find_all_by_entrytype(Community::USERCONTRIBUTED, @filteredparams.order) 
    end
  end
  
  def institutions
    @displayfilter = params[:displayfilter].nil? ? 'all' : params[:displayfilter]
    
    case @displayfilter
    when 'system'
      @landgrant = Institution.find_all_by_entrytype(Institution::LANDGRANT, :order => 'name') 
      @state = Institution.find_all_by_entrytype(Institution::STATE, :order => 'name') 
      @federal = Institution.find_all_by_entrytype(Institution::FEDERAL, :order => 'name') 
    when 'landgrant'
      @landgrant = Institution.find_all_by_entrytype(Institution::LANDGRANT, :order => 'name') 
    when 'state'
      @state = Institution.find_all_by_entrytype(Institution::STATE, :order => 'name') 
    when 'federal'
      @federal = Institution.find_all_by_entrytype(Institution::FEDERAL, :order => 'name') 
    when 'usercontributed'
      @usercontributed = Institution.find_all_by_entrytype(Institution::USERCONTRIBUTED, :order => 'name') 
    else
      @filter = 'all'
      @landgrant = Institution.find_all_by_entrytype(Institution::LANDGRANT, :order => 'name') 
      @state = Institution.find_all_by_entrytype(Institution::STATE, :order => 'name') 
      @federal = Institution.find_all_by_entrytype(Institution::FEDERAL, :order => 'name') 
      @usercontributed = Institution.find_all_by_entrytype(Institution::USERCONTRIBUTED, :order => 'name') 
    end
  end
  
  def locations
    @locations = Location.find(:all, :order => 'entrytype,name')
  end
  
  def positions
    @positions = Position.find(:all, :order => 'entrytype,name') 
  end
  
  def applications
    @applications = ActivityApplication.find(:all, :order => 'displayname') 
  end
  
  def list
    @filteredparams = FilterParams.new(params)
    @filteredparams.order=@filteredparams.order('activities.created_at','DESC')
    @findoptions = @filteredparams.findoptions
    @filterstring = @filteredparams.filter_string

    @page_title = "Activity"
    feedtitle = "Activity Atom Feed #{@filterstring}"
    
    
    urlparams = @filteredparams.option_values_hash.merge({:feedkey => @currentuser.feedkey})
    urlparams.delete(:dateinterval)
    urlparams.delete(:datefield)
    urlparams.merge!({:controller => '/people/feeds', :action => :list})
    @feedurl = url_for(urlparams)    
    @feedlink = "<link rel='alternate' type='application/atom+xml' href='#{@feedurl}', title='#{feedtitle}' />"
    
    
    # download check    
    if(!params[:download].nil? and params[:download] == 'csv')
      # nothing
    else
      @findoptions.merge!({:paginate => true, :page => params[:page]})
      @activitylist = Activity.filtered(@findoptions).paginate(:all, :page => params[:page], :order => @filteredparams.order)
      if((@activitylist.length) > 0)
        urloptions = @filteredparams.option_values_hash
        urloptions.merge!({:paginate => true, :page => params[:page]})
        urloptions.merge!({:action => :list, :download => 'csv'})
        @csvreporturl = CGI.escapeHTML(url_for(urloptions))
      end
    end
    

    respond_to do |format|
      format.html # show.html.erb
    end    
  end

  
end