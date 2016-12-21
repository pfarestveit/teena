require_relative '../util/spec_helper'

module Page

  class CanvasPage

    include PageObject
    include Logging
    include Page

    link(:profile_link, id: 'global_nav_profile_link')
    div(:footer, id: 'element_toggler_0')

    h2(:updated_terms_heading, xpath: '//h2[contains(text(),"Updated Terms of Use")]')
    checkbox(:terms_cbx, name: 'user[terms_of_use]')
    button(:accept_course_invite, name: 'accept')
    link(:masquerade_link, class: 'masquerade_button')
    link(:stop_masquerading_link, class: 'stop_masquerading')
    h2(:recent_activity_heading, xpath: '//h2[contains(text(),"Recent Activity")]')

    # Loads the Canvas homepage
    def load_homepage
      logger.info "Loading Canvas homepage at #{Utils.canvas_base_url}"
      navigate_to "#{Utils.canvas_base_url}"
    end

    # Loads the Canvas homepage and logs in to CalNet
    # @param cal_net [Page::CalNetPage]
    # @param username [String]
    # @param password [String]
    def log_in(cal_net, username, password)
      load_homepage
      cal_net.log_in(username, password)
    end

    # Shifts to default content, logs out, and waits for CalNet logout confirmation
    # @param driver [Selenium::WebDriver]
    # @param cal_net [Page::CalNetPage]
    def log_out(driver, cal_net)
      driver.switch_to.default_content
      wait_for_page_update_and_click profile_link_element
      wait_for_page_update_and_click profile_form_element
      wait_for_page_update_and_click logout_link_element if logout_link_element.exists?
      cal_net.logout_conf_heading_element.when_visible
    end

    # Masquerades as a user and then loads a course site
    # @param user [User]
    # @param course [Course]
    def masquerade_as(user, course)
      logger.info "Masquerading as #{user.role} #{user.username}"
      navigate_to "#{Utils.canvas_base_url}/users/#{user.canvas_id.to_s}/masquerade"
      wait_for_page_load_and_click masquerade_link_element
      stop_masquerading_link_element.when_visible
      load_course_site course
    end

    # Quits masquerading as another user
    def stop_masquerading
      logger.debug 'Ending masquerade'
      load_homepage
      wait_for_page_load_and_click stop_masquerading_link_element
      stop_masquerading_link_element.when_not_visible Utils.medium_wait
    end

    # Loads the QA sub-account page
    def load_sub_account
      navigate_to "#{Utils.canvas_base_url}/accounts/#{Utils.canvas_sub_account}"
    end

    # Hides the footer element in order to interact with elements hidden beneath it. Clicks once to set focus on the footer
    # and once again to hide it.
    def hide_footer
      footer_element.click
      sleep 1
      footer_element.click
    end

    # COURSE SITE SETUP

    link(:create_site_link, xpath: '//a[contains(text(),"Create a Site")]')

    link(:add_new_course_button, xpath: '//a[contains(.,"Add a New Course")]')
    select_list(:term, id: 'enrollment_term_id')
    text_area(:course_name_input, xpath: '//label[@for="course_name"]/../following-sibling::td/input')
    text_area(:ref_code_input, id: 'course_course_code')
    span(:create_course_button, xpath: '//span[contains(.,"Add Course")]')

    h2(:course_site_heading, xpath: '//div[@id="course_home_content"]/h2')
    text_area(:search_course_input, id: 'course_name')
    button(:search_course_button, xpath: '//input[@id="course_name"]/following-sibling::button')
    li(:add_course_success, xpath: '//li[contains(.,"successfully added!")]')

    link(:add_people_button, id: 'addUsers')
    text_area(:user_list, id: 'user_list_textarea')
    select_list(:user_role, id: 'role_id')
    button(:next_button, id: 'next-step')
    button(:add_button, id: 'createUsersAddButton')
    paragraph(:add_users_success, xpath: '//p[contains(.,"The following users have been enrolled")]')
    button(:done_button, xpath: '//button[contains(.,"Done")]')
    td(:default_email, xpath: '//th[text()="Default Email:"]/following-sibling::td')
    link(:edit_user_link, xpath: '//a[@class="edit_user_link"]')
    text_area(:user_email, id: 'user_email')
    button(:update_details_button, xpath: '//button[text()="Update Details"]')

    div(:publish_div, id: 'course_status_actions')
    button(:publish_button, class: 'btn-publish')
    button(:save_and_publish_button, class: 'save_and_publish')
    button(:published_button, class: 'btn-published')
    button(:submit_button, xpath: '//button[contains(.,"Submit")]')
    form(:profile_form, class: 'ic-NavMenu-profile-header-logout-form')
    button(:logout_link, xpath: '//button[text()="Logout"]')

    # Clicks the 'create a site' button for the Junction LTI tool
    # @param driver [Selenium::WebDriver]
    def click_create_site(driver)
      wait_for_page_load_and_click create_site_link_element
      switch_to_canvas_iframe driver
    end

    # Loads a course site and handles prompts that can appear
    # @param course [Course]
    def load_course_site(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}"
      wait_until { current_url.include? "#{course.site_id}" }
      if updated_terms_heading?
        logger.info 'Accepting terms and conditions'
        terms_cbx_element.when_visible Utils.short_wait
        check_terms_cbx
        submit_button
      end
      recent_activity_heading_element.when_visible
      if accept_course_invite?
        logger.info 'Accepting course invite'
        accept_course_invite
        accept_course_invite_element.when_not_visible Utils.medium_wait
      end
    end

    # Searches for a course site using a unique identifier
    # @param test_id [String]
    # @return [String]
    def search_for_course(test_id)
      tries ||= 3
      logger.info 'Searching for course site'
      load_sub_account
      search_course_input_element.when_visible timeout=Utils.short_wait
      self.search_course_input = "#{test_id}"
      search_course_button
      wait_until(timeout) { course_site_heading.include? "#{test_id}" }
      current_url.sub("#{Utils.canvas_base_url}/courses/", '')
    rescue => e
      logger.error('Course site not found, retrying')
      retry unless (tries -= 1).zero?
    end

    # Uses a hash to add users of defined roles to a course site. The hash is often derived from an external test data file
    # @param course [Course]
    # @param test_users [Hash]
    def add_users(course, test_users)
      ['Teacher', 'Designer', 'Lead TA', 'TA', 'Observer', 'Reader', 'Student'].each do |user_role|
        users = ''
        test_users.each { |user| users << "#{user.uid}, " if user.role == user_role }
        if users.empty?
          logger.warn "No test users with role #{user_role}"
        else
          begin
            # Canvas add-user function is often flaky in test envs, so retry if it fails
            tries ||= 3
            logger.info "Adding users with role #{user_role}"
            navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/users"
            wait_for_page_load_and_click add_people_button_element
            user_list_element.when_visible Utils.short_wait
            self.user_list = users
            self.user_role = user_role
            next_button
            wait_for_page_load_and_click add_button_element
            add_users_success_element.when_visible Utils.medium_wait
            done_button
          rescue
            logger.warn 'Add User failed, retrying'
            retry unless (tries -=1).zero?
          end
        end
      end
    end

    # Changes users' Canvas email addresses to the email defined for each in test data. This enables SuiteC email testing.
    # @param course [Course]
    # @param test_users [Array<User>]
    def reset_user_email(course, test_users)
      test_users.each do |user|
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/users/#{user.canvas_id}"
        default_email_element.when_visible Utils.short_wait
        if default_email == user.email
          logger.debug "Test user '#{user.full_name}' already has an updated default email"
        else
          logger.debug "Resetting test user #{user.full_name}'s email to #{user.email}"
          wait_for_page_load_and_click edit_user_link_element
          wait_for_element_and_type(user_email_element, user.email)
          wait_for_page_update_and_click update_details_button_element
          default_email_element.when_visible Utils.short_wait
        end
      end
    end

    # Creates standard Canvas course site, publishes it, and adds test users.
    # @param course [Course]
    # @param test_users [Array<User>]
    # @param test_id [String]
    def create_generic_course_site(course, test_users, test_id)
      if course.site_id.nil?
        logger.info "Creating a course site named #{course.code} in #{course.term} semester"
        load_sub_account
        wait_for_page_update_and_click add_new_course_button_element
        course_name_input_element.when_visible Utils.short_wait
        course.title = "QA Test - #{test_id}" if course.title.nil?
        course.code = "QA #{test_id} LEC001" if course.code.nil?
        self.course_name_input = "#{course.title}"
        self.ref_code_input = "#{course.code}"
        wait_for_element_and_select(term_element, course.term) unless course.term.nil?
        add_course_success_element.when_visible Utils.medium_wait
        course.site_id = search_for_course test_id
      else
        load_course_site course
      end
      logger.info 'Publishing the course'
      publish_div_element.when_visible Utils.short_wait
      wait_for_page_update_and_click publish_button_element unless published_button?
      published_button_element.when_visible Utils.medium_wait
      logger.info "Course site URL is #{current_url}"
      current_url.sub("#{Utils.canvas_base_url}/courses/", '')
      logger.info "Course ID is #{course.site_id}"
      add_users(course, test_users)
      load_course_site course
    end

    # Creates standard course site and then customizes it for SuiteC testing by setting test user emails and adding
    # SuiteC tools required for the test
    # @param course [Course]
    # @param test_users [Array<User>]
    # @param test_id [String]
    # @param tools [Array<SuiteCTools>]
    def get_suite_c_test_course(course, test_users, test_id, tools)
      course.title = "QA SuiteC Test #{test_id}" if course.site_id.nil?
      create_generic_course_site(course, test_users, test_id)
      reset_user_email(course, test_users)
      tools.each { |tool| add_suite_c_tool(course, tool) unless tool_nav_link(tool).exists? }
      load_course_site course
    end

    button(:delete_course_button, xpath: '//button[text()="Delete Course"]')
    li(:delete_course_success, xpath: '//li[contains(.,"successfully deleted")]')

    # Deletes a course site
    # @param course [Course]
    def delete_course(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/confirm_action?event=delete"
      wait_for_page_load_and_click delete_course_button_element
      delete_course_success_element.when_visible Utils.medium_wait
      logger.info "Course id #{course.site_id} has been deleted"
    end

    # SUITEC LTI TOOLS

    link(:apps_link, text: 'Apps')
    link(:navigation_link, text: 'Navigation')
    link(:view_apps_link, text: 'View App Configurations')
    link(:add_app_link, class: 'add_tool_link')
    select_list(:config_type, id: 'configuration_type_selector')
    text_area(:app_name_input, xpath: '//input[@placeholder="Name"]')
    text_area(:key_input, xpath: '//input[@placeholder="Consumer key"]')
    text_area(:secret_input, xpath: '//input[@placeholder="Shared Secret"]')
    text_area(:url_input, xpath: '//input[@placeholder="Config URL"]')
    button(:save_app_nav_button, xpath: '//button[text()="Save"]')

    # Returns the link element for the configured LTI tool on the course site sidebar
    # @param tool [SuiteCTools]
    # @return [PageObject::Elements::Link]
    def tool_nav_link(tool)
      link_element(text: "#{tool.name}")
    end

    # Loads the LTI tool configuration page for a course site
    # @param course [Course]
    def load_tools_config_page(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings/configurations"
    end

    # Adds a SuiteC LTI tool to a course site
    # @param course [Course]
    # @param tool [SuiteCTools]
    def add_suite_c_tool(course, tool)
      logger.info "Adding #{tool.name}"

      # Load the new tool configuration UI
      load_tools_config_page course
      wait_for_page_update_and_click apps_link_element
      wait_for_page_update_and_click add_app_link_element
      wait_for_element_and_select(config_type_element, 'By URL')
      # Use JS to select the option too since the WebDriver method is not working consistently
      execute_script('document.getElementById("configuration_type_selector").value = "url";')
      sleep 1

      # Enter the tool config
      wait_for_page_update_and_click app_name_input_element
      self.app_name_input = "#{tool.name}"
      self.key_input = Utils.lti_key
      self.secret_input = Utils.lti_secret
      self.url_input = "#{Utils.suite_c_base_url}#{tool.xml}"
      submit_button
      link_element(xpath: "//td[@title='#{tool.name}']").when_present

      # Move the tool from disabled to enabled
      load_tools_config_page course
      wait_for_page_update_and_click navigation_link_element
      hide_footer
      wait_for_page_update_and_click link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a")
      wait_for_page_update_and_click link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a[@title='Enable this item']")
      list_item_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]").when_visible Utils.short_wait
      save_app_nav_button
      tool_nav_link(tool).when_visible Utils.medium_wait
    end

    # Clicks the navigation link for a tool and returns the tool's URL
    # @param driver [Selenium::WebDriver]
    # @param tool [SuiteCTools]
    # @return [String]
    def click_tool_link(driver, tool)
      driver.switch_to.default_content
      hide_footer
      scroll_to_bottom
      wait_for_page_update_and_click tool_nav_link(tool)
      logger.info "#{tool.name} URL is #{current_url}"
      current_url.delete '#'
    end

    # ANNOUNCEMENTS

    link(:html_editor_link, xpath: '//a[contains(.,"HTML Editor")]')
    text_area(:announcement_msg, name: 'message')
    button(:save_announcement_button, xpath: '//h1[contains(text(),"New Discussion")]/following-sibling::div/button[contains(text(),"Save")]')
    h1(:announcement_title_heading, class: 'discussion-title')

    # Creates an announcement on a course site
    # @param course [Course]
    # @param announcement [Announcement]
    def create_announcement(course, announcement)
      logger.info "Creating announcement: #{announcement.title}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/discussion_topics/new?is_announcement=true"
      wait_for_element_and_type(discussion_title_element, announcement.title)
      html_editor_link if html_editor_link_element.visible?
      wait_for_element_and_type(announcement_msg_element, announcement.body)
      wait_for_page_update_and_click save_announcement_button_element
      announcement_title_heading_element.when_visible Utils.medium_wait
      logger.info "Announcement URL is #{current_url}"
      announcement.url = current_url.gsub!('discussion_topics', 'announcements')
    end

    # DISCUSSIONS

    link(:new_discussion_link, id: 'new-discussion-btn')
    text_area(:discussion_title, id: 'discussion-title')
    checkbox(:threaded_discussion_cbx, id: 'threaded')
    checkbox(:graded_discussion_cbx, id: 'use_for_grading')
    elements(:discussion_reply, :list_item, xpath: '//ul[@class="discussion-entries"]/li')
    link(:primary_reply_link, xpath: '//article[@id="discussion_topic"]//a[@data-event="addReply"]')
    link(:primary_html_editor_link, xpath: '//article[@id="discussion_topic"]//a[contains(.,"HTML Editor")]')
    text_area(:primary_reply_input, xpath: '//article[@id="discussion_topic"]//textarea[@class="reply-textarea"]')
    button(:primary_post_reply_button, xpath: '//article[@id="discussion_topic"]//button[contains(.,"Post Reply")]')
    elements(:secondary_reply_link, :link, xpath: '//li[@class="entry"]//a[@data-event="addReply"]')
    elements(:secondary_html_editor_link, :link, xpath: '//li[@class="entry"]//a[contains(.,"HTML Editor")]')
    elements(:secondary_reply_input, :text_area, xpath: '//li[@class="entry"]//textarea[@class="reply-textarea"]')
    elements(:secondary_post_reply_button, :button, xpath: '//li[@class="entry"]//button[contains(.,"Post Reply")]')

    # Clicks the 'save and publish' button using JavaScript rather than WebDriver
    def click_save_and_publish
      scroll_to_bottom
      click_element_js save_and_publish_button_element
    end

    # Creates a discussion on a course site
    # @param course [Course]
    # @param discussion [Discussion]
    def create_discussion(course, discussion)
      logger.info "Creating discussion topic named '#{discussion.title}'"
      load_course_site course
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/discussion_topics"
      wait_for_page_load_and_click new_discussion_link_element
      wait_for_element_and_type(discussion_title_element, discussion.title)
      check_threaded_discussion_cbx
      click_save_and_publish
      published_button_element.when_visible Utils.medium_wait
      logger.info "Discussion URL is #{current_url}"
      discussion.url = current_url
    end

    # Adds a reply to a discussion.  If an index is given, then adds a reply to an existing reply at that index.  Otherwise,
    # adds a reply to the topic itself.
    # @param discussion [Discussion]
    # @param index [Integer]
    # @param reply_body [String]
    def add_reply(discussion, index, reply_body)
      navigate_to discussion.url
      if index.nil?
        logger.info "Creating new discussion entry with body '#{reply_body}'"
        wait_for_page_load_and_click primary_reply_link_element
        primary_html_editor_link if primary_html_editor_link_element.visible?
        wait_for_element_and_type(primary_reply_input_element, reply_body)
        replies = discussion_reply_elements.length
        primary_post_reply_button
      else
        logger.info "Replying to a discussion entry at index #{index} with body '#{reply_body}'"
        wait_until { secondary_reply_link_elements.any? }
        wait_for_page_load_and_click secondary_reply_link_elements[index]
        secondary_html_editor_link_elements[index].click if secondary_html_editor_link_elements[index].visible?
        wait_until(Utils.short_wait) { secondary_reply_input_elements.any? }
        wait_for_element_and_type(secondary_reply_input_elements[index], reply_body)
        replies = discussion_reply_elements.length
        hide_footer
        secondary_post_reply_button_elements[index].click
      end
      wait_until(Utils.short_wait) { discussion_reply_elements.length == replies + 1 }
    end

    # ASSIGNMENTS

    link(:new_assignment_link, text: 'Assignment')
    select_list(:assignment_type, id: 'assignment_submission_type')
    text_area(:assignment_name, id: 'assignment_name')
    text_area(:assignment_due_date, class: 'DueDateInput')
    checkbox(:online_url_cbx, id: 'assignment_online_url')
    checkbox(:online_upload_cbx, id: 'assignment_online_upload')
    checkbox(:text_entry_cbx, id: 'assignment_text_entry')

    h1(:assignment_title_heading, class: 'title')
    link(:submit_assignment_link, text: 'Submit Assignment')
    link(:resubmit_assignment_link, text: 'Re-submit Assignment')
    link(:assignment_file_upload_tab, class: 'submit_online_upload_option')
    text_area(:file_upload_input, name: 'attachments[0][uploaded_data]')
    button(:file_upload_submit_button, id: 'submit_file_button')
    link(:assignment_site_url_tab, class: 'submit_online_url_option')
    text_area(:url_upload_input, id: 'submission_url')
    button(:url_upload_submit_button, xpath: '(//button[@type="submit"])[2]')
    div(:assignment_submission_conf, xpath: '//div[contains(.,"Turned In!")]')

    # Creates an assignment on a course site
    # @param course [Course]
    # @param assignment [Assignment]
    def create_assignment(course, assignment)
      logger.info "Creating submission assignment named '#{assignment.title}'"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/assignments/new"
      wait_for_element_and_type(assignment_name_element, assignment.title)
      wait_for_element_and_type(assignment_due_date_element, assignment.due_date.strftime("%b %-d %Y")) unless assignment.due_date.nil?
      assignment_type_element.when_visible Utils.medium_wait
      self.assignment_type = 'Online'
      online_url_cbx_element.when_visible Utils.short_wait
      check_online_url_cbx
      check_online_upload_cbx
      click_save_and_publish
      published_button_element.when_visible Utils.medium_wait
      logger.info "Submission assignment URL is #{current_url}"
      assignment.url = current_url
    end

    # Upload's a user's asset as an assignment submission
    # @param assignment [Assignment]
    # @param user [User]
    # @submission [Asset]
    def submit_assignment(assignment, user, submission)
      logger.info "Submitting #{submission.title} for #{user.full_name}"
      navigate_to assignment.url
      wait_for_page_load_and_click submit_assignment_link_element
      case submission.type
        when 'File'
          file_upload_input_element.when_visible Utils.short_wait
          self.file_upload_input_element.send_keys Utils.test_data_file_path(submission.file_name)
          wait_for_page_update_and_click file_upload_submit_button_element
        when 'Link'
          wait_for_page_update_and_click assignment_site_url_tab_element
          url_upload_input_element.when_visible Utils.short_wait
          self.url_upload_input = submission.url
          wait_for_page_update_and_click url_upload_submit_button_element
        else
          logger.error 'Unsupported submission type in test data'
      end
      assignment_submission_conf_element.when_visible Utils.long_wait
    end
  end
end
