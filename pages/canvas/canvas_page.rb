require_relative '../../util/spec_helper'

module Page

  class CanvasPage

    include PageObject
    include Logging
    include Page

    h2(:updated_terms_heading, xpath: '//h2[contains(text(),"Updated Terms of Use")]')
    checkbox(:terms_cbx, name: 'user[terms_of_use]')
    button(:accept_course_invite, name: 'accept')
    link(:masquerade_link, class: 'masquerade_button')
    link(:stop_masquerading_link, class: 'stop_masquerading')
    h2(:recent_activity_heading, xpath: '//h2[contains(text(),"Recent Activity")]')

    button(:submit_button, xpath: '//button[contains(.,"Submit")]')
    button(:save_button, xpath: '//button[text()="Save"]')
    button(:update_course_button, xpath: '//button[contains(.,"Update Course Details")]')
    li(:update_course_success, xpath: '//li[contains(.,"successfully updated")]')
    form(:profile_form, class: 'ic-NavMenu-profile-header-logout-form')
    link(:profile_link, id: 'global_nav_profile_link')
    button(:logout_link, xpath: '//button[text()="Logout"]')

    h1(:unexpected_error_msg, xpath: '//h1[contains(text(),"Unexpected Error")]')
    h2(:unauthorized_msg, xpath: '//h2[contains(text(),"Unauthorized")]')

    # Loads the Canvas homepage
    def load_homepage
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
      wait_for_update_and_click_js profile_link_element
      wait_for_update_and_click_js profile_form_element
      wait_for_update_and_click_js logout_link_element if logout_link_element.exists?
      cal_net.username_element.when_visible
    end

    # Masquerades as a user and then loads a course site
    # @param driver [Selenium::WebDriver]
    # @param user [User]
    # @param course [Course]
    def masquerade_as(driver, user, course = nil)
      load_homepage
      sleep 2
      stop_masquerading(driver) if stop_masquerading_link?
      logger.info "Masquerading as #{user.role} UID #{user.uid}"
      navigate_to "#{Utils.canvas_base_url}/users/#{user.canvas_id.to_s}/masquerade"
      wait_for_load_and_click masquerade_link_element
      stop_masquerading_link_element.when_visible
      load_course_site(driver, course) unless course.nil?
    end

    # Quits masquerading as another user
    # @param driver [Selenium::WebDriver]
    def stop_masquerading(driver)
      logger.debug 'Ending masquerade'
      load_homepage
      wait_for_load_and_click stop_masquerading_link_element
      stop_masquerading_link_element.when_not_visible(Utils.medium_wait) rescue Selenium::WebDriver::Error::StaleElementReferenceError
    end

    # Loads a given sub-account page
    def load_sub_account(sub_account)
      logger.debug "Loading sub-account #{sub_account}"
      navigate_to "#{Utils.canvas_base_url}/accounts/#{sub_account}"
    end

    # COURSE SITE SETUP

    link(:create_site_link, xpath: '//a[contains(text(),"Create a Site")]')

    link(:add_new_course_button, xpath: '//a[contains(.,"Add a New Course")]')
    select_list(:term, id: 'course_enrollment_term_id')
    text_area(:course_name_input, xpath: '//label[@for="course_name"]/../following-sibling::td/input')
    text_area(:ref_code_input, id: 'course_course_code')
    span(:create_course_button, xpath: '//span[contains(.,"Add Course")]')

    span(:course_site_heading, xpath: '//li[contains(@id,"crumb_course_")]//span')
    text_area(:search_course_input, id: 'course_name')
    button(:search_course_button, xpath: '//input[@id="course_name"]/following-sibling::button')
    li(:add_course_success, xpath: '//li[contains(.,"successfully added!")]')

    link(:course_details_link, text: 'Course Details')
    text_area(:course_title, id: 'course_name')
    text_area(:course_code, id: 'course_course_code')

    button(:delete_course_button, xpath: '//button[text()="Delete Course"]')
    li(:delete_course_success, xpath: '//li[contains(.,"successfully deleted")]')

    # Creates standard Canvas course site in a given sub-account, publishes it, and adds test users.
    # @param driver [Selenium::WebDriver]
    # @param sub_account [String]
    # @param course [Course]
    # @param test_users [Array<User>]
    # @param test_id [String]
    # @param tools [Array<SuiteCTools>]
    def create_generic_course_site(driver, sub_account, course, test_users, test_id, tools = nil)
      if course.site_id.nil?
        load_sub_account sub_account
        wait_for_load_and_click add_new_course_button_element
        course_name_input_element.when_visible Utils.short_wait
        course.title = "QA Test - #{Time.at test_id.to_i}" if course.title.nil?
        course.code = "QA #{Time.at test_id.to_i} LEC001" if course.code.nil?
        self.course_name_input = "#{course.title}"
        self.ref_code_input = "#{course.code}"
        logger.info "Creating a course site named #{course.title} in #{course.term} semester"
        wait_for_update_and_click_js create_course_button_element
        add_course_success_element.when_visible Utils.medium_wait
        course.site_id = search_for_course(course, sub_account)
        unless course.term.nil?
          navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
          wait_for_element_and_select_js(term_element, course.term)
          wait_for_update_and_click_js update_course_button_element
          update_course_success_element.when_visible Utils.medium_wait
        end
      else
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
        course_details_link_element.when_visible Utils.medium_wait
        course.title = course_title
        course.code = course_code
      end
      publish_course_site(driver, course)
      logger.info "Course ID is #{course.site_id}"
      add_users(course, test_users)
      if tools
        tools.each do |tool|
          add_suite_c_tool(course, tool) unless tool_nav_link(tool).exists?
          disable_tool(course, tool) unless tools.include? tool
        end
      end
    end

    # Clicks the 'create a site' button for the Junction LTI tool
    # @param driver [Selenium::WebDriver]
    def click_create_site(driver)
      wait_for_load_and_click create_site_link_element
      switch_to_canvas_iframe driver
    end

    # Loads a course site and handles prompts that can appear
    # @param driver [Selenium::WebDriver]
    # @param course [Course]
    def load_course_site(driver, course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}"
      wait_until { current_url.include? "#{course.site_id}" }
      if updated_terms_heading?
        logger.info 'Accepting terms and conditions'
        terms_cbx_element.when_visible Utils.short_wait
        check_terms_cbx
        submit_button
      end
      div_element(id: 'content').when_present Utils.medium_wait
      if accept_course_invite?
        logger.info 'Accepting course invite'
        accept_course_invite
        accept_course_invite_element.when_not_visible Utils.medium_wait
      end
    end

    # Searches a sub-account for a course site using a unique identifier
    # @param course [Course]
    # @param sub_account [String]
    # @return [String]
    def search_for_course(course, sub_account)
      tries ||= 6
      logger.info "Searching for '#{course.code}'"
      load_sub_account sub_account
      wait_for_element_and_type(search_course_input_element, "#{course.code}")
      wait_for_update_and_click search_course_button_element
      wait_until(Utils.short_wait) { course_site_heading.include? "#{course.code}" }
      current_url.sub("#{Utils.canvas_base_url}/courses/", '')
    rescue
      logger.error('Course site not found, retrying')
      sleep Utils.short_wait
      (tries -= 1).zero? ? fail : retry
    end

    div(:publish_div, id: 'course_status_actions')
    button(:publish_button, class: 'btn-publish')
    button(:save_and_publish_button, class: 'save_and_publish')
    button(:published_button, class: 'btn-published')
    form(:published_status, id: 'course_status_form')
    label(:activity_stream_radio, xpath: '//span[contains(.,"Course Activity Stream")]/ancestor::label')
    button(:choose_and_publish_button, xpath: '//div[@aria-label="Choose Course Home Page"]//span[contains(.,"Choose and Publish")]/..')

    # Publishes a course site
    # @param driver [Selenium::WebDriver]
    # @param course [Course]
    def publish_course_site(driver, course)
      logger.info 'Publishing the course'
      load_course_site(driver, course)
      published_status_element.when_visible Utils.short_wait
      if published_button?
        logger.debug 'The site is already published'
      else
        logger.debug 'The site is unpublished, publishing'
        wait_for_update_and_click publish_button_element
        # Junction test courses from SIS data always have a term and have the site's front page set during creation. Other
        # test courses never have a term and need to set the site's front page while publishing.
        if course.term.nil?
          wait_for_update_and_click activity_stream_radio_element
          wait_for_update_and_click choose_and_publish_button_element
        end
        published_button_element.when_present Utils.medium_wait
      end
    end

    # Deletes a course site
    # @param driver [Selenium::WebDriver]
    # @param course [Course]
    def delete_course(driver, course)
      load_homepage
      stop_masquerading(driver) if stop_masquerading_link?
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/confirm_action?event=delete"
      wait_for_load_and_click_js delete_course_button_element
      delete_course_success_element.when_visible Utils.medium_wait
      logger.info "Course id #{course.site_id} has been deleted"
    end

    # COURSE USERS

    select_list(:enrollment_roles, name: 'enrollment_role_id')
    link(:add_people_button, id: 'addUsers')
    link(:help_finding_users_link, id: 'add-people-help')
    link(:find_person_to_add_link, xpath: '//a[contains(.,"Find a Person to Add")]')
    checkbox(:add_user_by_email, xpath: '//span[contains(text(),"Email Address")]/..')
    checkbox(:add_user_by_uid, xpath: '//span[contains(text(),"Berkeley UID")]/..')
    checkbox(:add_user_by_sid, xpath: '//span[contains(text(),"Student ID")]/..')
    text_area(:user_list, xpath: '//textarea')
    select_list(:user_role, id: 'peoplesearch_select_role')
    button(:next_button, id: 'addpeople_next')
    div(:users_ready_to_add_msg, xpath: '//div[contains(text(),"The following users are ready to be added to the course.")]')
    li(:remove_user_success, xpath: '//li[contains(.,"User successfully removed")]')
    button(:done_button, xpath: '//button[contains(.,"Done")]')
    td(:default_email, xpath: '//th[text()="Default Email:"]/following-sibling::td')
    link(:edit_user_link, xpath: '//a[@class="edit_user_link"]')
    text_area(:user_email, id: 'user_email')
    button(:update_details_button, xpath: '//button[text()="Update Details"]')

    text_area(:search_user_input, xpath: '//input[@placeholder="Search people"]')

    # Loads the course users page
    # @param course [Course]
    def load_users_page(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/users"
      div_element(xpath: '//div[@data-view="users"]').when_present Utils.medium_wait
    end

    # Scrolls down the users table until a given set of users appear in the table
    # @param users [User]
    def wait_for_users(users)
      scroll_to_bottom
      users.each do |user|
        wait_until(Utils.short_wait) { cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]").exists? }
      end
    end

    # Adds a collection of users to a course site with the role associated with the user
    # @param course [Course]
    # @param test_users [Array<User>]
    def add_users(course, test_users)
      users_to_add = Array.new test_users
      logger.info "Users needed for the site are #{users_to_add.map { |u| u.uid }}"

      # Users already on the site with the right role do not need to be added again
      users_missing = []
      load_users_page course
      sleep Utils.short_wait
      scroll_to_bottom
      users_to_add.each do |user|
        users_missing << user unless cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]//td[contains(.,'#{user.role}')]").exists?
      end
      logger.info "Users who need to be added are #{users_missing.map { |u| u.uid }}"

      # Add users by role
      ['Teacher', 'Designer', 'Lead TA', 'TA', 'Observer', 'Reader', 'Student'].each do |user_role|
        users = ''
        users_with_role = users_missing.select { |user| user.role == user_role }
        users_with_role.each { |user| users << "#{user.uid}, " }
        unless users.empty?
          begin
            # Canvas add-user function is often flaky in test envs, so retry if it fails
            tries ||= 3
            logger.info "Adding users with role #{user_role}"
            load_users_page course
            wait_for_load_and_click add_people_button_element
            add_user_by_uid_element.when_visible Utils.short_wait
            sleep 1
            check_add_user_by_uid
            wait_for_element_and_type_js(user_list_element, users)
            self.user_role = user_role
            wait_for_update_and_click_js next_button_element
            users_ready_to_add_msg_element.when_visible Utils.medium_wait
            hide_canvas_footer
            wait_for_update_and_click_js next_button_element
            wait_for_users users_with_role
          rescue => e
            logger.error "#{e.message}\n#{e.backtrace}"
            logger.warn 'Add User failed, retrying'
            (tries -= 1).zero? ? fail : retry
          end
        end
      end

      # Set test users' email to address in test data in order to test email sending
      reset_user_email(course, users_missing)
    end

    # Removes users from a course site
    # @param course [Course]
    # @param users [Array<User>]
    def remove_users_from_course(course, users)
      load_users_page course
      hide_canvas_footer
      wait_for_users users
      users.each do |user|
        logger.info "Removing #{user.role} UID #{user.uid} from course site ID #{course.site_id}"
        wait_for_update_and_click link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[contains(@class,'al-trigger')]")
        confirm(true) { wait_for_update_and_click link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[@data-event='removeFromCourse']") }
        remove_user_success_element.when_visible Utils.short_wait
      end
    end

    # Searches for a user by Canvas user ID
    # @param user [User]
    def search_user_by_canvas_id(user)
      wait_for_element_and_type(search_user_input_element, user.canvas_id)
      sleep 1
    end

    # Changes users' Canvas email addresses to the email defined for each in test data. This enables SuiteC email testing.
    # @param course [Course]
    # @param test_users [Array<User>]
    def reset_user_email(course, test_users)
      test_users.each do |user|
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/users/#{user.canvas_id}"
        default_email_element.when_present Utils.short_wait
        if default_email == user.email
          logger.debug "Test user '#{user.full_name}' already has an updated default email"
        else
          logger.debug "Resetting test user #{user.full_name}'s email to #{user.email}"
          wait_for_load_and_click_js edit_user_link_element
          wait_for_element_and_type_js(user_email_element, user.email)
          wait_for_update_and_click_js update_details_button_element
          default_email_element.when_present Utils.short_wait
        end
      end
    end

    # Returns the UID displayed for a user on a course site roster
    # @param canvas_id [Integer]
    # @return [String]
    def roster_user_uid(canvas_id)
      cell_element(xpath: "//tr[contains(@id,'#{canvas_id}')]/td[3]").text
    end

    # Returns the text in the table cell containing a user's enrolled section codes
    # @param canvas_id [Integer]
    # @return [String]
    def roster_user_sections(canvas_id)
      cell_element(xpath: "//tr[contains(@id,'#{canvas_id}')]/td[5]").text
    end

    # Returns the text in the table cell containing a user's roles
    # @param canvas_id [Integer]
    # @return [String]
    def roster_user_roles(canvas_id)
      cell_element(xpath: "//tr[contains(@id,'#{canvas_id}')]/td[6]").text
    end

    # Clicks the Canvas Add People button followed by the Find a Person to Add button and switches to the LTI tool
    # @param driver [Selenium::WebDriver]
    def click_find_person_to_add(driver)
      logger.debug 'Clicking Find a Person to Add button'
      wait_for_load_and_click add_people_button_element
      wait_for_load_and_click find_person_to_add_link_element
      switch_to_canvas_iframe driver
    end

    # Waits for a course site's enrollment to finish updating for a given set of user roles and then returns the final count for each role
    # @param course [Course]
    # @param roles [Array<String>]
    # @return [Array<Integer>]
    def wait_for_enrollment_import(course, roles)
      enrollment_counts = []
      roles.each do |role|
        starting_count = 0
        ending_count = enrollment_count_by_role(course, role)
        begin
          starting_count = ending_count
          sleep 20
          ending_count = enrollment_count_by_role(course, role)
        end while ending_count > starting_count
        enrollment_counts << ending_count
      end
      enrollment_counts
    end

    # Returns the number of users in a course site with a given role
    # @param course [Course]
    # @param role [String]
    # @return Integer
    def enrollment_count_by_role(course, role)
      load_users_page course
      wait_for_load_and_click enrollment_roles_element
      role_option = enrollment_roles_options.find { |option| option.include? role }
      count = role_option.delete("#{role} ()").to_i
      logger.debug "The count of #{role} users is currently #{count}"
      count
    end

    # SUITEC LTI TOOLS

    link(:apps_link, text: 'Apps')
    link(:navigation_link, text: 'Navigation')
    link(:view_apps_link, text: 'View App Configurations')
    link(:add_app_link, class: 'add_tool_link')
    select_list(:config_type, id: 'configuration_type_selector')
    text_area(:app_name_input, xpath: '//input[@placeholder="Name"]')
    text_area(:key_input, xpath: '//input[@placeholder="Consumer Key"]')
    text_area(:secret_input, xpath: '//input[@placeholder="Shared Secret"]')
    text_area(:url_input, xpath: '//input[@placeholder="Config URL"]')

    # Returns the link element for the configured LTI tool on the course site sidebar
    # @param tool [SuiteCTools]
    # @return [PageObject::Elements::Link]
    def tool_nav_link(tool)
      link_element(xpath: "//ul[@id='section-tabs']//a[text()='#{tool.name}']")
    end

    # Loads the LTI tool configuration page for a course site
    # @param course [Course]
    def load_tools_config_page(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings/configurations"
    end

    # Loads the site navigation page
    # @param course [Course]
    def load_navigation_page(course)
      load_tools_config_page course
      wait_for_update_and_click navigation_link_element
      hide_canvas_footer
    end

    # Enables an LTI tool that is already installed
    # @param course [Course]
    # @param tool [SuiteCTools]
    def enable_tool(course, tool)
      load_navigation_page course
      wait_for_update_and_click_js link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a")
      wait_for_update_and_click_js link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a[@title='Enable this item']")
      list_item_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]").when_visible Utils.medium_wait
      save_button
      tool_nav_link(tool).when_visible Utils.medium_wait
    end

    # Disables an LTI tool that is already installed
    # @param course [Course]
    # @param tool [SuiteCTools]
    def disable_tool(course, tool)
      logger.info "Disabling #{tool.name}"
      load_navigation_page course
      if verify_block { link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a").when_present 2 }
        logger.debug "#{tool.name} is already installed but disabled, skipping"
      else
        if link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a").exists?
          logger.debug "#{tool.name} is installed and enabled, disabling"
          wait_for_update_and_click_js link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a")
          wait_for_update_and_click_js link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a[@title='Disable this item']")
          list_item_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]").when_visible Utils.medium_wait
          save_button
          tool_nav_link(tool).when_not_visible Utils.medium_wait
          pause_for_poller
        else
          logger.debug "#{tool.name} is not installed, skipping"
        end
      end
    end

    # Adds a SuiteC LTI tool to a course site
    # @param course [Course]
    # @param tool [SuiteCTools]
    def add_suite_c_tool(course, tool)
      logger.info "Adding and/or enabling #{tool.name}"
      load_tools_config_page course
      wait_for_update_and_click navigation_link_element
      hide_canvas_footer
      if verify_block { link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a").when_present 2 }
        logger.debug "#{tool.name} is already installed and enabled, skipping"
      else
        if link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a").exists?
          logger.debug "#{tool.name} is already installed but disabled, enabling"
          enable_tool(course, tool)
          pause_for_poller
        else
          logger.debug "#{tool.name} is not installed, installing and enabling"
          wait_for_update_and_click apps_link_element
          wait_for_update_and_click add_app_link_element

          # Enter the tool config
          config_type_element.when_visible Utils.short_wait
          self.config_type = 'By URL'
          # Use JS to select the option too since the WebDriver method is not working consistently
          execute_script('document.getElementById("configuration_type_selector").value = "url";')
          sleep 1
          wait_for_update_and_click_js app_name_input_element
          self.app_name_input = "#{tool.name}"
          self.key_input = Utils.suitec_lti_key
          self.secret_input = Utils.suitec_lti_secret
          self.url_input = "#{Utils.suite_c_base_url}#{tool.xml}"
          submit_button
          link_element(xpath: "//td[@title='#{tool.name}']").when_present Utils.medium_wait
          enable_tool(course, tool)
        end
      end
    end

    # Clicks the navigation link for a tool and returns the tool's URL
    # @param driver [Selenium::WebDriver]
    # @param tool [SuiteCTools]
    # @return [String]
    def click_tool_link(driver, tool)
      driver.switch_to.default_content
      hide_canvas_footer
      wait_for_update_and_click_js tool_nav_link(tool)
      wait_until(Utils.medium_wait) { title == "#{tool.name}" }
      logger.info "#{tool.name} URL is #{current_url}"
      current_url.delete '#'
    end

  end
end
