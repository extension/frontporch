# === COPYRIGHT:
#  Copyright (c) 2005-2006 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

require 'zip_code_to_state'

class ExpertController < ApplicationController
  layout  'aae'  
  
  has_rakismet :only => [:submit_question, :widget_submit]
  
  skip_before_filter :check_authorization
  before_filter :login_required, :except => [:email_escalation_report, :expert_widget]
  before_filter :set_current_user, :except => [:email_escalation_report, :expert_widget]
  
  def assign
    if !params[:id]
      flash[:failure] = "You must select a question to assign."
      go_back
      return
    end
    
    @submitted_question = SubmittedQuestion.find_by_id(params[:id])
    @categories = Category.root_categories
        
    if !@submitted_question
      flash[:failure] = "Invalid question."
      go_back
      return
    end
    
    if request.post?
      if !params[:assignee_login]
        flash[:failure] = "You must select a user."
        go_back
        return
      end
      
      user = User.find_by_login(params[:assignee_login])
      
      if !user or user.retired?
        !user ? err_msg = "User does not exist." : err_msg = "User is retired from the system"
        flash[:failure] = err_msg
        go_back
        return
      end
      
      (params[:assign_comment] and params[:assign_comment].strip != '') ? assign_comment = params[:assign_comment] : assign_comment = nil
      
      if (previous_assignee = @submitted_question.assignee) and (User.current_user != previous_assignee)
        assigned_to_someone_else = true
      end
      
      @submitted_question.assign_to(user, User.current_user, assign_comment)
      
      # if the question is currently assigned to someone,
      # send a notification email to the user it's assigned to to let them know the question has been assigned to someone else to reduce duplication of efforts
      ExpertMailer.deliver_assigned(@submitted_question, url_for(:controller => 'expert', :action => 'question', :id => @submitted_question), request.host)
      ExpertMailer.deliver_reassign_notification(@submitted_question, url_for(:controller => 'expert', :action => 'question', :id => @submitted_question), previous_assignee.email, request.host) if assigned_to_someone_else
            
      redirect_to :action => 'question', :id => @submitted_question
    end
  end
  
  def profile_tooltip
    @user = User.find_by_login(params[:login])
    
    if @user
      render :template => 'expert/profile_tooltip.js.rjs'
    else
      render :nothing => true
    end
  end
  
  def assignees_by_cat_loc
    @category = Category.find(:first, :conditions => ["id = ?", params[:category]]) if params[:category] and params[:category].strip != ''
    @location = Location.find(:first, :conditions => ["fipsid = ?", params[:location]]) if params[:location] and params[:location].strip != ''
    @county = County.find(:first, :conditions => ["fipsid = ? and state_fipsid = ?", params[:county], @location.fipsid]) if @location and params[:county] and params[:county].strip != ''
    
    setup_cat_loc
    render :partial => "search_expert", :layout => false
  end
  
  def assignees_by_name
    #if a login/name was typed into the field to search for users
    login_str = params[:login]
    if !login_str or login_str.strip == ""
      render :nothing => true
      return
    end
    
    #split on comma delimited or space delimited input
    #examples of possibilities of input include:
    #lastname,firstname
    #lastname, firstname
    #lastname firstname
    #firstname,lastname
    #firstname lastname
    #loginid
    user_name = login_str.strip.split(%r{\s*,\s*|\s+})
    
    #if comma or space delimited...
    if user_name.length > 1
      @users = User.find(:all, :include => [:locations, :open_questions, :categories], :limit => 20, :conditions => ['((first_name like ? and last_name like ?) or (last_name like ? and first_name like ?)) and users.retired = false', user_name[0] + '%', user_name[1] + '%', user_name[0] + '%', user_name[1] + '%'], :order => 'first_name')
    #else only a single word was typed
    else
      @users = User.find(:all, :include => [:locations, :open_questions, :categories], :limit => 20, :conditions => ['(login like ? or first_name like ? or last_name like ?) and users.retired = false', user_name[0] + '%', user_name[0] + '%', user_name[0] + '%'], :order => 'first_name')
    end
    
    render :template => 'expert/assignees_by_name.js.rjs', :layout => false
    
  end
  
  def ask_an_expert
    session[:return_to] = params[:redirect_to]
    flash.now[:googleanalytics] = '/ask-an-expert-form'
    
    set_title("Ask an Expert - eXtension", "New Question")
    set_titletag("Ask an Expert - eXtension")

    # if we are editing
    if params[:expert_question]
      flash.now[:googleanalytics] = '/ask-an-expert-edit-question'
      set_titletag("Edit your Question - eXtension")
      begin
        @expert_question = ExpertQuestion.new(params[:expert_question])
      rescue
        @expert_question = ExpertQuestion.new
      end
      @expert_question.valid?      
    else
      @expert_question = ExpertQuestion.new_from_personal(@personal)      
    end
  
    @locations = Location.find(:all)
  end
  
  def location
    if params[:id]
      @location = Location.find(:first, :conditions => ["fipsid = ?", params[:id].to_i])
      if !@location
        flash[:failure] = "Invalid Location Entered"
        redirect_to home_url
      else
        @users = @location.users.find(:all, :order => "users.first_name")
      end
    else
      flash[:failure] = "Invalid Location Entered"
      redirect_to home_url
    end
  end
  
  def widget
    @widget = Widget.find(params[:id])
    if !@widget
      flash[:notice] = "The widget you specified does not exist."
      redirect_to :controller => :account, :action => :widget_preferences
      return
    end
    @widget_assignees = @widget.assignees
  end
  
  def show_profile
    @user = User.find(params[:id])
    respond_to do |format|
      format.js
    end
  end
  
  def category
    #if all users with an expertise in a category were selected
    if params[:id]
      @category = Category.find(:first, :conditions => ["id = ?", params[:id].strip])
      
      if @category
        @category_name = @category.name
        @users = @category.users.find(:all, :select => "users.*", :order => "users.first_name", :include => :locations)
        @combined_users = get_answering_users(@users) if @users.length > 0
      else
        flash[:failure] = "Invalid Category"
        request.env["HTTP_REFERER"] ? (redirect_to :back) : (redirect_to home_url)
        return
      end
    else
      flash[:failure] = "Invalid Category"
      request.env["HTTP_REFERER"] ? (redirect_to :back) : (redirect_to home_url)
      return
    end
  end
  
  def email_escalation_report
    cutoff_date = Time.new - (24 * 60 * 60 * 2) # two days

    Category.root_categories.each do |category|
      submitted_questions = SubmittedQuestion.find_with_category(category, :all, :conditions => ["external_app_id IS NOT NULL and spam = false and status_state = ? and submitted_questions.created_at < ?", SubmittedQuestion::STATUS_SUBMITTED, cutoff_date], :order => 'submitted_questions.created_at asc')
      
      if submitted_questions.length > 0
        escalation_users_for_category = SubmittedQuestion.question_escalators_by_category(category)
        emails = escalation_users_for_category.collect{|eu| eu.email} if escalation_users_for_category
      end
      
      if emails
        email = ExpertMailer.create_escalation(emails, submitted_questions, url_for(:controller => 'expert', :action => 'escalation_report', :id => category), request.host)
        email.set_content_type("text/plain")
        ExpertMailer.deliver(email)
      end
    end
    
    render :text => "Email sent.", :layout => false
  end
 
  # Get counties for location selected for aae question filtering
  def get_counties
    if params[:location] and params[:location].strip != Location::ALL
      location = Location.find(:first, :conditions => ["fipsid = ?", params[:location].strip])
      @counties = location.counties.find(:all, :order => 'name', :conditions => "countycode <> '0'")
    else
      @counties = nil
    end
    render :layout => false
  end
  
  def question_confirmation
    #q must be used for google to recognize
    if !params[:q] or params[:q].strip == '' || !params[:expert_question]
      flash[:notice] = "You must enter valid text into the question field."
      return redirect_to( {:action => 'ask_an_expert'}.update( flatten_hash_for_url( {:expert_question => params[:expert_question]} ) ))
    end
    params[:expert_question][:asked_question] = params[:q]
    flash.now[:googleanalytics] = '/ask-an-expert-search-results'
    set_title("Ask an Expert - eXtension", "Confirmation")
    set_titletag("Search Results for Ask an Expert - eXtension")
    
    @expert_question = ExpertQuestion.new(params[:expert_question])
    @expert_question.status = 'submitted'
    @flattened_eq_parameters = flatten_hash_for_url( {:expert_question => params[:expert_question]} )
    unless @expert_question.valid?
      return redirect_to( {:action => 'ask_an_expert'}.update( @flattened_eq_parameters ))
    end

    formatted_question = params[:q].strip.upcase
    
    if ExpertQuestion.find(:first, :conditions => ["submitted_by = ? and (UCase(trim(asked_question)) = trim(?))", session[:user_id], formatted_question])
      flash[:notice] = "Our records indicate that you have already submitted this question.<br />Please do not submit a question more than once."
      redirect_to :action => 'ask_an_expert', 
      :location_selected => params[:location_option], :county_selected => params[:county_option], :question => params[:q]
      return
    end  
  end
  
  def submit_question
    @expert_question = ExpertQuestion.new(params[:expert_question])
    @expert_question.status = 'submitted'
    @expert_question.user_ip = request.remote_ip
    @expert_question.user_agent = request.env['HTTP_USER_AGENT']
    @expert_question.referrer = request.env['HTTP_REFERER']
    @expert_question.spam = @expert_question.spam?    
    
    if !@expert_question.valid? || !@expert_question.save
      flash[:notice] = 'There was an error saving your question. Please try again.'
      redirect_to :action => 'ask_an_expert'
      return
    end
    
    flash[:notice] = 'Your question has been submitted and the answer will be sent to your email. Our experts try to answer within 48 hours.'
    flash[:googleanalytics] = '/ask-an-expert-question-submitted'
    if session[:return_to]
      redirect_to(session[:return_to]) 
    else
      redirect_to '/'
    end
  end
  
  # TODO: fill out this method
  # receives and saves the question submitted from a widget
  def widget_submit
    
  end
  
  # Show the expert form to answer an external question
  def answer_question
    @submitted_question = SubmittedQuestion.find_by_id(params[:squid])
    
    if !@submitted_question
      flash[:failure] = "Invalid question."
      go_back
      return
    end
    
    if @submitted_question.resolved?
      flash[:failure] = "This question has already been resolved.<br />It could have been resolved while you were working on it.<br />We appreciate your help in resolving these questions!"
      redirect_to :controller => :expert, :action => :question, :id => @submitted_question.id
      return
    end
    
    @status = params[:status_state]
    @question = Question.find_by_id(params[:question]) if params[:question]
    @sampletext = params[:sample] if params[:sample]
    signature_pref = User.current_user.user_preferences.find_by_name('signature')
    signature_pref ? @signature = signature_pref.setting : @signature = "-#{User.current_user.get_first_last_name}"
    
    if @submitted_question.get_submitter_name != SubmittedQuestion::DEFAULT_SUBMITTER_NAME
      @external_name = @submitted_question.get_submitter_name
    else
      @extenal_name = nil
    end
  
    if request.post?
      answer = params[:current_response]

      if !answer or '' == answer.strip
        @signature = params[:signature]
        flash[:failure] = "You must not leave the answer blank."
        return
      end
      
      @question ? contributing_faq = @question.id : contributing_faq = nil
      (@status and @status.to_i == SubmittedQuestion::STATUS_NO_ANSWER) ? sq_status = SubmittedQuestion::STATUS_NO_ANSWER : sq_status = SubmittedQuestion::STATUS_RESOLVED
      
      @submitted_question.update_attributes(:status => SubmittedQuestion.convert_to_string(sq_status), :status_state =>  sq_status, :resolved_by => User.current_user, :current_response => answer, :resolver_email => User.current_user.email, :current_contributing_faq => contributing_faq)  
      @submitter_email = @submitted_question.external_submitter
      
      @url_var = 'http://www.extension.org'
      
      if params[:signature] and params[:signature].strip != ''
        @signature = params[:signature]
      else
        @signature = nil
      end
      
      email = FaqMailer.create_response_email(@submitter_email, @submitted_question, @external_name, @url_var, @signature)      
      email.set_content_type("text/plain")
      FaqMailer.deliver(email)  
  	  
      flash[:success] = "Your answer has been sent to the person who asked the question.<br />
                        You can now save the question as an FAQ, or exit this screen without saving."
        
      redirect_to :action => 'question_answered', :question => @submitted_question.asked_question, :answer => @submitted_question.current_response, :squid => @submitted_question.id
    end

  end
  
  # Display the confirmation for answering a question
  def question_answered
    @submitted_question = SubmittedQuestion.find_by_id(params[:squid])
    
    if !@submitted_question
      flash[:failure] = "Invalid question."
      go_back
      return
    end
    
    @question = @submitted_question.to_faq(User.current_user)
    @revision = @question.revisions[0]

    if params[:question] && params[:answer]
      @revision.question_text = params[:question]
      @revision.answer = params[:answer]  
    end
  end
  
  # Display the "new FAQ form" when resolving an "ask an expert" question
  def new_faq
    @submitted_question = SubmittedQuestion.find_by_id(params[:squid])
    
    if !@submitted_question
      flash[:failure] = "Invalid question."
      go_back
      return
    end
    
    @question = @submitted_question.to_faq(User.current_user)
    @revision = @question.revisions[0]

    if params[:question] && params[:answer]
      @revision.question_text = params[:question]
      @revision.answer = params[:answer]  
    end
    
    @user_popular_tags = User.current_user.popular_tags(10)
    render :layout => "heureka"
  end

  # Save the new FAQ used to resolve an "ask an expert" question
  def create
    @submitted_question = SubmittedQuestion.find(params[:squid])

    @question = Question.new(params[:question])
    
    #remove all whitespace in questions and answers before putting into db.
    params[:revision].collect{|key, val| params[:revision][key] = val.strip}
    
    @revision = Revision.new(params[:revision])
    
    @revision.user = User.current_user 

    #set up @revision.reference_string
    handle_ref_question_numbers(@revision)
 
    @question.status = Question::STATUS_DRAFT
    @question.draft_status = Question::STATUS_DRAFT
    
    if !valid_ref_question?
      flash[:failure] = "Invalid question number entered."
      error_render("new_faq")
      return
    end
    
    @question.revise(@revision)
    @question.submitted_questions << @submitted_question
    
    if @question.save
	    if session[:watch_pref] == "1"
        User.current_user.questions << @question
        User.current_user.save
      end
      
      @question.tag_with(User.current_user.id, params[:tag_list].strip) if (params[:tag_list] and params[:tag_list].strip != '')
      
      flash[:success] = "Your new FAQ has been saved"
      # remove any list context in the session so that return to list, next question, etc. 
      # will not show up when viewing the newly created faq
      session[:context] = nil
      redirect_to :controller => 'questions', :action => 'show', :id => @question.id
    else
      flash[:failure] = "There was an error saving the new faq. Please try again."
      error_render("new_faq")
    end	      
  end # end create
  
  def show_faq
    @question = Question.find_by_id(params[:id])
    @submitted_question = SubmittedQuestion.find_by_id(params[:squid])
    
    if !@question or !@submitted_question
      go_back
      return
    end
  end

  # Detail page for an ask an expert question
  def question
    @submitted_question = SubmittedQuestion.find_by_id(params[:id])
    
    if @submitted_question.nil?
      do_404
      return
    end
    
    @categories = Category.root_categories
    @category_options = @categories.map{|c| [c.name,c.id]}
      
    if @submitted_question.external_submitter && @submitted_question.external_submitter.strip != ""
      @submitter_email = @submitted_question.external_submitter
    else
      @submitter_email = "Not Available"
    end
    
    @submitter_name = @submitted_question.get_submitter_name
      
    if @submitted_question.categories and @submitted_question.categories.length > 0
      @category = @submitted_question.categories.first
      @category = @category.parent if @category.parent
      @category_id = @category.id
      @users = @category.users.find(:all, :select => "users.*", :order => "users.first_name")
    # find subcategories
      @sub_category_options = [""].concat(@category.children.map{|sq| [sq.name, sq.id]})
      if subcategory = @submitted_question.categories.find(:first, :conditions => "parent_id IS NOT NULL")
        @sub_category_id = subcategory.id
      end
    else
      @sub_category_options = [""]    
    end
  end

  def assigned
    if err_msg = params_errors
      list_view_error(err_msg)
      return
    end
    
    #set the instance variables based on parameters
    list_view
    set_filters
    @questions_status = SubmittedQuestion::STATUS_SUBMITTED
    if params[:id]
      @user = User.find_by_id(params[:id])
      
      if !@user
        flash[:failure] = "Invalid user."
        go_back
        return
      end
      
    else
      @user = User.current_user
    end
    
    # find questions that are marked as being currently worked on
    @reserved_questions = SubmittedQuestionEvent.reserved_questions.collect{|sq| sq.id}
    
    # user's assigned submitted questions filtered by submitted question filter
    @filtered_submitted_questions = SubmittedQuestion.find_submitted_questions(SubmittedQuestion::SUBMITTED_TEXT, @category, @location, @county, @source, nil, @user, nil, false, false, @order)
    
    # total user's assigned submitted questions (unfiltered)
    @total_submitted_questions = SubmittedQuestion.find_submitted_questions(SubmittedQuestion::SUBMITTED_TEXT, nil, nil, nil, nil, nil, @user, nil, false, false, @order)

    # the difference in count between the filtered and unfiltered questions
    @question_difference = @total_submitted_questions.length - @filtered_submitted_questions.length
    
    @questions_not_in_filter = @total_submitted_questions - @filtered_submitted_questions if @question_difference > 0
    
    # decide which set of submitted questions (filtered or unfiltered) get shown in the list view
    @filtered_submitted_questions.length == 0 ? @submitted_questions = @total_submitted_questions : @submitted_questions = @filtered_submitted_questions
  end
  
  def enable_search_by_name
    @submitted_question = SubmittedQuestion.find_by_id(params[:id])
    render :layout => false
  end
  
  def enable_search_by_cat_loc
    @submitted_question = SubmittedQuestion.find(:first, :conditions => ["id = ?", params[:id]])
    @category = @submitted_question.categories.find(:first, :conditions => "categories.parent_id IS NULL")
    @location = @submitted_question.location
    @county = @submitted_question.county
    setup_cat_loc
    
    render :layout => false
  end
  
  def enable_category_change
    if request.post?
      @submitted_question = SubmittedQuestion.find_by_id(params[:id])
  
      @category_options = Category.root_categories.map{|c| [c.name,c.id]}
      if parent_category = @submitted_question.categories.find(:first, :conditions => "parent_id IS NULL")
        @category_id = parent_category.id
        @sub_category_options = [""].concat(parent_category.children.map{|sq| [sq.name, sq.id]})
        if subcategory = @submitted_question.categories.find(:first, :conditions => "parent_id IS NOT NULL")
          @sub_category_id = subcategory.id
        end
      else
        @sub_category_options = [""]
      end
      render :layout => false
    end
  end
  
  def change_category
    if request.post?
      @submitted_question = SubmittedQuestion.find(params[:sq_id].strip)
      category_param = "category_#{@submitted_question.id}"
      parent_category = Category.find(params[category_param].strip) if params[category_param] and params[category_param].strip != '' and params[category_param].strip != "uncat"
      sub_category = Category.find(params[:sub_category].strip) if params[:sub_category] and params[:sub_category].strip != ''
      @submitted_question.categories.clear
      if params[category_param].strip != "uncat"
        @submitted_question.categories << parent_category if parent_category
        @submitted_question.categories << sub_category if sub_category
      end
      @submitted_question.save
      SubmittedQuestionEvent.log_recategorize(@submitted_question, User.current_user, @submitted_question.category_names)
    end
    
    respond_to do |format|
      format.js
    end
    
  end
  
  def reserve_question
    if request.post?
      if params[:sq_id] and @submitted_question = SubmittedQuestion.find_by_id(params[:sq_id].strip) and !@submitted_question.resolved?
        if User.current_user.id != @submitted_question.assignee.id
          previous_assignee_email = @submitted_question.assignee.email
          @submitted_question.assign_to(User.current_user, User.current_user, nil) 
          # if the question is currently assigned to someone,
          # send a notification email to the user it's assigned to to let them know the question has been assigned to someone else to reduce duplication of efforts
          ExpertMailer.deliver_assigned(@submitted_question, url_for(:controller => 'expert', :action => 'question', :id => @submitted_question), request.host)
          ExpertMailer.deliver_reassign_notification(@submitted_question, url_for(:controller => 'expert', :action => 'question', :id => @submitted_question), previous_assignee_email, request.host) 
        end
        SubmittedQuestionEvent.log_working_on(@submitted_question, User.current_user)
        redirect_to :controller => :expert, :action => :question, :id => @submitted_question.id
      else
        flash[:message] = "Invalid submitted question number."
        redirect_to :controller => :expert, :action => :incoming
      end
    else
      do_404
      return
    end
  end
  
  def get_subcats
    parent_cat = Category.find_by_id(params[:category].strip) if params[:category] and params[:category].strip != '' and params[:category].strip != "uncat"
    if parent_cat 
      @sub_category_options = [""].concat(parent_cat.children.map{|sq| [sq.name, sq.id]})
    else
      @sub_category_options = [""]
    end
    
    render :layout => false
  end
  
  # Lists unresolved ask an expert questions
  def incoming
    if err_msg = params_errors
      list_view_error(err_msg)
      return
    end
    #set the instance variables based on parameters
    list_view
    set_filters
    
    @reserved_questions = SubmittedQuestionEvent.reserved_questions.collect{|sq| sq.id}
    @questions_status = SubmittedQuestion::STATUS_SUBMITTED
    @submitted_questions = SubmittedQuestion.find_submitted_questions(SubmittedQuestion::SUBMITTED_TEXT, @category, @location, @county, @source, nil, nil, params[:page], true, false, @order)
  end

  # Lists all resolved ask an expert questions including answered, not answered, and rejected
  def resolved
    if err_msg = params_errors
      list_view_error(err_msg)
      return
    end
    
    # set the instance variables based on parameters
    list_view(true)
    set_filters
    
    case params[:type]
    when 'all'
      sq_query_method = SubmittedQuestion::RESOLVED_TEXT
      @questions_status = SubmittedQuestion::STATUS_RESOLVED
    when nil
      sq_query_method = SubmittedQuestion::RESOLVED_TEXT
      @questions_status = SubmittedQuestion::STATUS_RESOLVED
    when 'answered'
      sq_query_method = SubmittedQuestion::ANSWERED_TEXT
      @questions_status = SubmittedQuestion::ANSWERED_TEXT
      @page_title = 'Resolved/Answered Questions'
    when 'not_answered'
      sq_query_method = SubmittedQuestion::NO_ANSWER_TEXT
      @questions_status = SubmittedQuestion::STATUS_NO_ANSWER
      @page_title = 'Resolved/Not Answered Questions'
    when 'rejected'
      sq_query_method = SubmittedQuestion::REJECTED_TEXT
      @questions_status = SubmittedQuestion::STATUS_REJECTED
      @page_title = 'Resolved/Rejected Questions'
    else
      flash.now[:failure] = "Wrong type of resolved questions specified."
      @submitted_questions = []
      return
    end
    
    @submitted_questions = SubmittedQuestion.find_submitted_questions(sq_query_method, @category, @location, @county, @source, nil, nil, params[:page], true, false, @order)
  end
  
  def my_resolved
    if err_msg = params_errors
      list_view_error(err_msg)
      return
    end
    
    #set the instance variables based on parameters
    list_view(true)
    set_filters
    @questions_status = SubmittedQuestion::STATUS_RESOLVED
    @user = User.current_user
    
    # user's resolved submitted questions filtered by submitted question filter
    @filtered_submitted_questions = SubmittedQuestion.find_submitted_questions(SubmittedQuestion::RESOLVED_TEXT, @category, @location, @county, @source, @user, nil, params[:page], true, false, @order)
    
    # total user's resolved submitted questions (unfiltered)
    @total_submitted_questions = SubmittedQuestion.find_submitted_questions(SubmittedQuestion::RESOLVED_TEXT, nil, nil, nil, nil, @user, nil, params[:page], true, false, @order)  
    
    # the difference in count between the filtered and unfiltered questions
    @question_difference = @total_submitted_questions.total_entries - @filtered_submitted_questions.total_entries
    
    # decide which set of submitted questions (filtered or unfiltered) get shown in the list view
    @filtered_submitted_questions.total_entries == 0 ? @submitted_questions = @total_submitted_questions : @submitted_questions = @filtered_submitted_questions
  end
  
  #lists questions marked as spam
  def spam_list
    if err_msg = params_errors
      list_view_error(err_msg)
      return
    end
    
    #set the instance variables based on parameters  
    list_view
    set_filters
    
    # it does not matter if this question was previously reserved if it's spam
    @reserved_questions = []
    @questions_status = SubmittedQuestion::STATUS_SUBMITTED
    @submitted_questions = SubmittedQuestion.find_submitted_questions(SubmittedQuestion::SUBMITTED_TEXT, @category, @location, @county, @source, nil, nil, params[:page], true, true, @order)
  end
  
  def report_spam
    if request.post?      
      begin
        submitted_question = SubmittedQuestion.find(:first, :conditions => ["id = ?", params[:id]])
        if submitted_question
          submitted_question.update_attribute(:spam, true)
          SubmittedQuestionEvent.log_spam(submitted_question, User.current_user)       
          submitted_question.spam!
          flash[:success] = "Incoming question has been successfully marked as spam."
        else
          flash[:failure] = "Incoming question does not exist."
        end
        
      rescue Exception => ex
        flash[:failure] = "There was a problem reporting spam. Please try again at a later time."
        logger.error "Problem reporting spam at #{Time.now.to_s}\nError: #{ex.message}"
      end
      redirect_to :controller => :expert, :action => :incoming
    end
  end

  def report_ham
    if request.post?
      begin
        submitted_question = SubmittedQuestion.find(:first, :conditions => ["id = ?", params[:id]])
        if submitted_question
          submitted_question.update_attribute(:spam, false)
          SubmittedQuestionEvent.log_non_spam(submitted_question, User.current_user)
          submitted_question.ham!
          flash[:success] = "Incoming question has been successfully marked as non-spam."
          redirect_to :controller => :expert, :action => :question, :id => submitted_question.id
          return
        else
          flash[:failure] = "Incoming question does not exist."
        end
        
      rescue Exception => ex
        flash[:failure] = "There was a problem marking this question as non-spam. Please try again at a later time."
        logger.error "Problem reporting ham at #{Time.now.to_s}\nError: #{ex.message}"
      end
        
      redirect_to :controller => :expert, :action => :spam_list
    end   
  end

  def escalation_report
    cutoff_date = Time.new - (24 * 60 * 60 * 2) # two days
     
    if params[:id] == Category::UNASSIGNED
      @submitted_questions = SubmittedQuestion.find_uncategorized(:all, :conditions => ["external_app_id IS NOT NULL and spam = false and status_state = ? and submitted_questions.created_at < ?", SubmittedQuestion::STATUS_SUBMITTED, cutoff_date], :order => 'submitted_questions.created_at desc')
    elsif params[:id] and (category = Category.find(:first, :conditions => ["categories.id = ?", params[:id]]))
      @submitted_questions = SubmittedQuestion.find_with_category(category, :all, :conditions => ["external_app_id IS NOT NULL and spam = false and status_state = ? and submitted_questions.created_at < ?", SubmittedQuestion::STATUS_SUBMITTED, cutoff_date], :order => 'submitted_questions.created_at desc')
    else
      @submitted_questions = SubmittedQuestion.find(:all, :conditions => ["external_app_id IS NOT NULL and spam = false and status_state = ? and created_at < ?", SubmittedQuestion::STATUS_SUBMITTED, cutoff_date], :order => 'created_at desc')
    end
  end
  
  def reject    
    @submitted_question = SubmittedQuestion.find_by_id(params[:id])
    @submitter_name = @submitted_question.get_submitter_name
    if @submitted_question
      if @submitted_question.status_state == SubmittedQuestion::STATUS_RESOLVED or @submitted_question.status_state == SubmittedQuestion::STATUS_NO_ANSWER
        flash[:failure] = "This question has already been resolved."
        redirect_to :controller => :expert, :action => :question, :id => @submitted_question.id
        return
      end
      
      if request.post?
        message = params[:reject_message]
        if message.nil? or message.strip == ''
          flash.now[:failure] = "Please document a reason for the rejecting this question."
          render nil
          return
        end
        
        if @submitted_question.status_state == SubmittedQuestion::STATUS_RESOLVED or @submitted_question.status_state == SubmittedQuestion::STATUS_NO_ANSWER
          flash.now[:failure] = "This question has already been resolved."
          render nil
          return
        end   

        if @submitted_question.reject(User.current_user, message)
          flash[:success] = "The question has been rejected."
          redirect_to :controller => :expert, :action => :question, :id => @submitted_question
        else
          flash[:failure] = "The question did not get properly saved. Please try again."
          render :action => :reject
        end
      end        
    else
      flash[:failure] = "Question not found."
      redirect_to :controller => :expert, :action => :incoming
    end
  end
  
  def reactivate
    if request.post?
      @submitted_question = SubmittedQuestion.find_by_id(params[:id])
      @submitted_question.update_attributes(:status => SubmittedQuestion::SUBMITTED_TEXT, :status_state => SubmittedQuestion::STATUS_SUBMITTED, :resolved_by => nil, :current_response => nil, :resolved_at => nil, :resolver_email => nil)
      SubmittedQuestionEvent.log_reactivate(@submitted_question, User.current_user)
      flash[:success] = "Question re-activated"
      redirect_to :controller => :expert, :action => :question, :id => @submitted_question.id
    end
  end

  # Show a list of possible FAQs that could be used to resolve an ask an expert question
  def show_duplicates
    @errors = []
    @submitted_question = SubmittedQuestion.find_by_id(params[:squid])
    if !@submitted_question
      flash[:failure] = "Please specify a valid question."
      redirect_to home_url
      return
    end

    if params[:query].nil? || params[:query].strip.length == 0
      flash[:failure] = 'You must enter some search terms.'
      redirect_to :controller => :expert, :action => :question, :id => @submitted_question.id
      return
    end
    
    keywords = params[:query]
    
    begin
      @search_results = Question.full_text_search(keywords, 1, 'and')
    rescue Exception => e
      flash[:failure] = "The search could not be successfully completed.e" + e.message
      email_search_error(request.host, params[:query], e.message)
      redirect_to :action => :question, :query => params[:query], :id => params[:squid]
      return
    end
  end

  private
  
  def params_errors
    if params[:page] and params[:page].to_i == 0 
      return "Invalid page number"
    else
      return nil
    end
  end
  
  def list_view_error(err_msg)
    redirect_to :controller => :expert, :action => :incoming
    flash[:failure] = err_msg
  end
  
  def set_filters
    user = User.current_user
    source_filter_prefs = user.user_preferences.find(:all, :conditions => "name = '#{UserPreference::FILTER_WIDGET_ID}'").collect{|pref| pref.setting}.join(',')
    widgets_to_filter = Widget.find(:all, :conditions => "widgets.id IN (#{source_filter_prefs})", :order => "name") if source_filter_prefs and source_filter_prefs.strip != ''
    @source_options = [['All Sources', 'all'], ['www.extension.org', 'pubsite'], ['All Ask eXtension widgets', 'widget']]
    @source_options = @source_options.concat(widgets_to_filter.map{|w| [w.name, w.id.to_s]}) if widgets_to_filter
    @source_options = @source_options.concat([['', ''], ['Edit source list','add_sources']])
    @widget_filter_url = url_for(:controller => 'account', :action => 'widget_preferences', :only_path => false)
  end
  
  def error_render(action = "new_faq")
    @tag_string = params[:tag_list].strip if params[:tag_list]
    @user_popular_tags = User.current_user.popular_tags(10)
    
    @input_numbers=params['Numbers'] if params['Numbers'] and params['Numbers'].strip !=''
    @saved_reference_names = []
    if @revision.reference_string
      @saved_reference_names = @revision.reference_string.split(',')
    end
    render :action => action
  end
  
  def setup_cat_loc
    @location_options = [""].concat(Location.find(:all, :order => 'entrytype, name').map{|l| [l.name, l.fipsid]})
    @categories = Category.root_categories
    @category_options = @categories.map{|c| [c.name,c.id]}
    
    @county_fips = @county.fipsid if @county  
    @category_id = @category.id if @category
    @location_fips = @location.fipsid if @location
    
    # ToDo: need to change this id parameter name to something more descriptive
    @submitted_question = SubmittedQuestion.find(:first, :conditions => ["id = ?", params[:id]]) if not @submitted_question
    @users = User.find_by_cat_loc(@category, @location, @county)
  end
  
  def get_answering_users(selected_users)
    user_ids = selected_users.map{|u| u.id}.join(',')
    answering_role = Role.find_by_name(Role::AUTO_ROUTE)
    answering_users = answering_role.users.find(:all, :select => "users.*", :conditions => "users.id IN (#{user_ids})")
    user_intersection = selected_users & answering_users
  end
  
  def go_back
    request.env["HTTP_REFERER"] ? (redirect_to :back) : (redirect_to :action => 'incoming')
  end
  
  def filter_category_name
    id = get_filter_pref.setting if get_filter_pref
    
    return id if !id
    
    return id if id == Category::UNASSIGNED
    
    return Category.find(id).name
  end
  
  def email_aae_retrieve_error(host, error_message)
    message = "Error Message: " + error_message + "\n\n\n"
    email = ErrorMailer.create_aae_retrieve_error(host, message)
    email.set_content_type("text/plain")
    ErrorMailer.deliver(email)
  end
  
end
