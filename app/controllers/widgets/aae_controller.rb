# === COPYRIGHT:
#  Copyright (c) 2005-2010 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class Widgets::AaeController < ApplicationController
  before_filter :login_required, :except => [:index, :about, :documentation, :who, :login_redirect]
  before_filter :check_purgatory, :except => [:index, :about, :documentation, :who, :login_redirect]
  before_filter :login_optional, :only => [:index, :about, :documentation, :who]
  
  layout 'widgetshome'
  
  def redirector
    if params[:redirectparam] and self.respond_to?(params[:redirectparam])
      return redirect_to(:action => params[:redirectparam])
    else
      return redirect_to(:action => :index)
    end
  end
  
  def index
  end
  
  def who 
  end

  def documentation
  end

  def about 
  end
  
  def login_redirect
    session[:return_to] = params[:return_back]
    redirect_to :controller => 'people/account', :action => :login
  end
  
  def list
    if params[:id] and params[:id] == 'inactive'
      @widgets = Widget.get_all_with_assignee_count(:conditions => 'widgets.active = false')
      @selected_tab = :inactive
    else
      @selected_tab = :all
      @widgets = Widget.get_all_with_assignee_count(:conditions => 'widgets.active = true')
    end
  end
  
  def view
    if !(params[:id] and @widget = Widget.find(params[:id]))
      flash[:failure] = "You must specify a valid widget"
      redirect_to :action => :index
    else
      @widget_iframe_code = @widget.get_iframe_code
      @widget_assignees = @widget.assignees
      @non_active_assignees = @widget.non_active_assignees
    end
  end
  
  # created new named widget form
  def new
    @widget = Widget.new
  end

  # generates the iframe code for users to paste into their websites 
  # that pulls the widget code from this app with provided location and county
  def generate_widget_code
    @widget = Widget.new(params[:widget])
    
    if !@widget.valid?
      return render :template => '/widgets/aae/new'
    end
    
    # location and county
    if(params[:location_id] and location = Location.find_by_id(params[:location_id].strip.to_i))
      @widget.location = location
      if(params[:county_id] and county = County.find_by_id_and_location_id(params[:county_id].strip.to_i, location.id))
        @widget.county = county
      end
    end
    
    @widget.set_fingerprint(@currentuser)
    @widget.user = @currentuser
    
    if(@widget.save)
      # handle tags
      if(@widget.enable_tags?)
        @widget.tag_myself_with_shared_tags(params[:tag_list])
      end
      @currentuser.widgets << @widget
      
    else
      return render :template => '/widgets/aae/new'
    end
    
  end
  
  def edit
    if(!params[:id] or !(@widget = Widget.find_by_id(params[:id])))
      flash[:error] = "Missing widget id."
      return redirect_to(:action => 'index')
    end
  end
  
  def update
    if(!params[:id] or !(@widget = Widget.find_by_id(params[:id])))
      flash[:error] = "Missing widget id."
      return redirect_to(:action => 'index')
    end
    
    @widget.attributes = params[:widget]
    
    # location and county - separate from params[:widget], but probably shouldn't be
    if(params[:location_id] and location = Location.find_by_id(params[:location_id].strip.to_i))
      @widget.location = location
      if(params[:county_id] and county = County.find_by_id_and_location_id(params[:county_id].strip.to_i, location.id))
        @widget.county = county
      end
    end
    
    if !@widget.valid?
      return render :template => '/widgets/aae/edit'
    end
    
    
    if(@widget.save)
      # handle tags
      if(@widget.enable_tags?)
        @widget.tag_myself_with_shared_tags(params[:tag_list])
      end
      WidgetEvent.log_event(@widget.id, @currentuser.id, WidgetEvent::EDITED_ATTRIBUTES)
      return redirect_to(widgets_view_aae_url(:id => @widget.id))
    else
      return render :template => '/widgets/aae/edit'
    end
  end

  def get_widgets
    if params[:id] and params[:id] == 'inactive'
      @widgets = Widget.get_all_with_assignee_count(:conditions => "widgets.name LIKE '#{params[:widget_name]}%' AND widgets.active = false")
    else
      @widgets = Widget.get_all_with_assignee_count(:conditions => "widgets.name LIKE '#{params[:widget_name]}%' AND widgets.active = true")
    end
    render :partial => "widget_list", :layout => false
  end
  
end