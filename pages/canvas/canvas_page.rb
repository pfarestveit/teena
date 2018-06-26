require_relative '../../util/spec_helper'

module Page

  class CanvasPage

    include PageObject
    include Logging
    include Page

    h2(:updated_terms_heading, xpath: '//h2[contains(text(),"Updated Terms of Use")]')
    checkbox(:terms_cbx, name: 'user[terms_of_use]')
    button(:accept_course_invite, name: 'accept')
    link(:masquerade_link, xpath: '//a[contains(@href, "masquerade")]')
    link(:stop_masquerading_link, class: 'stop_masquerading')
    h2(:recent_activity_heading, xpath: '//h2[contains(text(),"Recent Activity")]')
    h3(:project_site_heading, xpath: '//h3[text()="Is bCourses Right For My Project?"]')

    button(:submit_button, xpath: '//button[contains(.,"Submit")]')
    button(:save_button, xpath: '//button[text()="Save"]')
    button(:update_course_button, xpath: '//button[contains(.,"Update Course Details")]')
    li(:update_course_success, xpath: '//li[contains(.,"successfully updated")]')
    form(:profile_form, xpath: '//form[@action="/logout"]')
    link(:profile_link, id: 'global_nav_profile_link')
    button(:logout_link, xpath: '//button[contains(.,"Logout")]')

    h1(:unexpected_error_msg, xpath: '//h1[contains(text(),"Unexpected Error")]')
    h2(:unauthorized_msg, xpath: '//h2[contains(text(),"Unauthorized")]')

    # Loads the Canvas homepage, optionally using a non-default Canvas base URL
    # @param canvas_base_url [String]
    def load_homepage(canvas_base_url = nil)
      logger.debug "Canvas base url is #{canvas_base_url}" if canvas_base_url
      canvas_base_url ? navigate_to(canvas_base_url) : navigate_to("#{Utils.canvas_base_url}")
    end

    # Loads the Canvas homepage and logs in to CalNet, optionally using a non-default Canvas base URL
    # @param cal_net [Page::CalNetPage]
    # @param username [String]
    # @param password [String]
    # @param canvas_base_url [String]
    def log_in(cal_net, username, password, canvas_base_url = nil)
      load_homepage canvas_base_url
      cal_net.log_in(username, password)
    end

    # Shifts to default content, logs out, and waits for CalNet logout confirmation
    # @param driver [Selenium::WebDriver]
    # @param cal_net [Page::CalNetPage]
    # @param event [Event]
    def log_out(driver, cal_net, event = nil)
      driver.switch_to.default_content
      wait_for_update_and_click_js profile_link_element
      wait_for_update_and_click_js profile_form_element
      wait_for_update_and_click_js logout_link_element if logout_link_element.exists?
      cal_net.username_element.when_visible
      add_event(event, EventType::LOGGED_OUT)
    end

    # Masquerades as a user and then loads a course site
    # @param driver [Selenium::WebDriver]
    # @param user [User]
    # @param course [Course]
    def masquerade_as(driver, user, course = nil)
      load_homepage
      sleep 2
      stop_masquerading(driver) if stop_masquerading_link?
      logger.info "Masquerading as #{user.role} UID #{user.uid}, Canvas ID #{user.canvas_id}"
      navigate_to "#{Utils.canvas_base_url}/users/#{user.canvas_id}/masquerade"
      wait_for_update_and_click masquerade_link_element
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

    # Clicks the 'save and publish' button using JavaScript rather than WebDriver
    def click_save_and_publish
      scroll_to_bottom
      wait_for_update_and_click_js save_and_publish_button_element
    end

    # COURSE SITE SETUP

    link(:create_site_link, xpath: '//a[contains(text(),"Create a Site")]')

    button(:add_new_course_button, xpath: '//span[text()="Course"]/parent::span/parent::button')
    text_area(:course_name_input, xpath: '//span[text()="Course Name"]/parent::span/parent::span/following-sibling::span//input')
    text_area(:ref_code_input, xpath: '//span[text()="Reference Code"]/parent::span/parent::span/following-sibling::span//input')
    select_list(:term, xpath:'//span[text()="Enrollment Term"]/parent::span/parent::span/following-sibling::span//select')
    button(:create_course_button, xpath: '//button[contains(.,"Add Course")]')

    span(:course_site_heading, xpath: '//li[contains(@id,"crumb_course_")]//span')
    text_area(:search_course_input, xpath: '//input[@placeholder="Search courses..."]')
    button(:search_course_button, xpath: '//input[@id="course_name"]/following-sibling::button')
    paragraph(:add_course_success, xpath: '//p[contains(.,"successfully added!")]')

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
    # @param tools [Array<LtiTools>]
    # @param event [Event]
    def create_generic_course_site(driver, sub_account, course, test_users, test_id, tools = nil, event = nil)
      if course.site_id.nil?
        # If creating a new SuiteC course site, inactivate all existing courses to avoid slow poller cycles
        SuiteCUtils.inactivate_all_courses if tools && ((tools & [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX, LtiTools::WHITEBOARDS, LtiTools::IMPACT_STUDIO]).any?)

        load_sub_account sub_account
        wait_for_load_and_click add_new_course_button_element
        course_name_input_element.when_visible Utils.short_wait
        course.title = "QA Test - #{Time.at test_id.to_i}" if course.title.nil?
        course.code = "QA #{Time.at test_id.to_i} LEC001" if course.code.nil?
        self.course_name_input = "#{course.title}"
        self.ref_code_input = "#{course.code}"
        logger.info "Creating a course site named #{course.title} in #{course.term} semester"
        wait_for_update_and_click create_course_button_element
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
      add_users(course, test_users, event)
      if tools
        tools.each do |tool|
          unless tool_nav_link(tool).exists?
            add_suite_c_tool(course, tool) if [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX, LtiTools::WHITEBOARDS, LtiTools::IMPACT_STUDIO].include? tool
            add_privacy_dashboard(course) if tool == LtiTools::PRIVACY_DASHBOARD
          end
          disable_tool(course, tool) unless tools.include? tool
        end
      end
    end

    # Clicks the 'create a site' button for the Junction LTI tool. If the click fails, the button could be behind a footer.
    # Retries after hiding the footer.
    # @param driver [Selenium::WebDriver]
    def click_create_site(driver)
      tries ||= 2
      wait_for_update_and_click create_site_link_element
    rescue
      execute_script('arguments[0].style.hidden="hidden";', div_element(id: 'fixed_bottom'))
      retry unless (tries -= 1).zero?
    ensure
      switch_to_canvas_iframe(driver, JunctionUtils.junction_base_url)
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
      logger.info "Searching for '#{course.title}'"
      load_sub_account sub_account
      wait_for_element_and_type(search_course_input_element, "#{course.title}")
      sleep 1
      wait_for_update_and_click link_element(text: "#{course.title}")
      wait_until(Utils.short_wait) { course_site_heading.include? "#{course.code}" }
      current_url.sub("#{Utils.canvas_base_url}/courses/", '')
    rescue
      logger.error('Course site not found, retrying')
      sleep Utils.short_wait
      (tries -= 1).zero? ? fail : retry
    end

    link(:course_details_tab, xpath: '//a[contains(.,"Course Details")]')
    text_area(:course_sis_id, id: 'course_sis_source_id')
    link(:sections_tab, xpath: '//a[contains(.,"Sections")]')
    text_area(:section_name, id: 'course_section_name')
    button(:add_section_button, xpath: '//button[@title="Add Section"]')
    link(:edit_section_link, class: 'edit_section_link')
    text_area(:section_sis_id, id: 'course_section_sis_source_id')
    button(:update_section_button, xpath: '//button[contains(.,"Update Section")]')

    # Adds a section to a course site and assigns SIS IDs to both the course and the section
    # @param course [Course]
    # @param section [Section]
    def add_sis_section_and_ids(course, section)
      # Add SIS id to course
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
      wait_for_load_and_click course_details_tab_element
      wait_for_element_and_type(course_sis_id_element, course.sis_id)
      wait_for_update_and_click update_course_button_element
      update_course_success_element.when_visible Utils.short_wait
      # Add unique section
      wait_for_update_and_click_js sections_tab_element
      wait_for_element_and_type(section_name_element, section.sis_id)
      wait_for_update_and_click add_section_button_element
      # Add SIS id to section
      wait_for_update_and_click link_element(text: section.sis_id)
      wait_for_update_and_click edit_section_link_element
      wait_for_element_and_type(section_sis_id_element, section.sis_id)
      wait_for_update_and_click update_section_button_element
      update_section_button_element.when_not_visible Utils.short_wait
    end

    div(:publish_div, id: 'course_status_actions')
    button(:publish_button, class: 'btn-publish')
    button(:save_and_publish_button, class: 'save_and_publish')
    button(:published_button, class: 'btn-published')
    form(:published_status, id: 'course_status_form')
    radio_button(:activity_stream_radio, xpath: '//span[contains(.,"Course Activity Stream")]/ancestor::label')
    button(:choose_and_publish_button, xpath: '//span[contains(.,"Choose and Publish")]/ancestor::button')

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
          activity_stream_radio_element.when_visible Utils.short_wait
          select_activity_stream_radio
          wait_for_update_and_click choose_and_publish_button_element
        end
        published_button_element.when_present Utils.medium_wait
      end
    end

    # Edits the course site title
    # @param course [Course]
    def edit_course_name(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
      wait_for_element_and_type(text_area_element(id: 'course_name'), course.title)
      wait_for_update_and_click button_element(xpath: '//button[contains(.,"Update Course Details")]')
      list_item_element(xpath: '//li[contains(.,"Course was successfully updated")]').when_present Utils.short_wait
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
    select_list(:user_section, id: 'peoplesearch_select_section')
    button(:next_button, id: 'addpeople_next')
    div(:users_ready_to_add_msg, xpath: '//div[contains(text(),"The following users are ready to be added to the course.")]')
    li(:remove_user_success, xpath: '//li[contains(.,"User successfully removed")]')
    button(:done_button, xpath: '//button[contains(.,"Done")]')
    td(:default_email, xpath: '//th[text()="Default Email:"]/following-sibling::td')
    link(:edit_user_link, xpath: '//a[@class="edit_user_link"]')
    text_area(:user_email, id: 'user_email')
    button(:update_details_button, xpath: '//button[text()="Update Details"]')

    cell(:user_login, xpath: '//b[@class="unique_id"]')
    link(:edit_user_login_link, xpath: '//a[@class="edit_pseudonym_link"]')
    text_area(:user_login_input, id: 'pseudonym_unique_id')
    button(:update_user_login_button, xpath: '//button[text()="Update Login"]')

    text_area(:search_user_input, xpath: '//input[@placeholder="Search people"]')

    # Loads the course users page, optionally using a non-default Canvas base URL
    # @param course [Course]
    def load_users_page(course, canvas_base_url = nil)
      canvas_base_url ?
          navigate_to("#{canvas_base_url}/courses/#{course.site_id}/users") :
          navigate_to("#{Utils.canvas_base_url}/courses/#{course.site_id}/users")
      div_element(xpath: '//div[@data-view="users"]').when_present Utils.medium_wait
    end

    # Scrolls down the users table until a given set of users appear in the table
    # @param users [Array<User>]
    def wait_for_users(users)
      scroll_to_bottom
      users.each do |user|
        wait_until(Utils.short_wait) { cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]").exists? }
      end
    end

    # Adds a collection of users to a course site with the role associated with the user
    # @param course [Course]
    # @param test_users [Array<User>]
    # @param section [Section]
    # @param event [Event]
    def add_users(course, test_users, section = nil, event = nil)
      users_to_add = Array.new test_users
      logger.info "Users needed for the site are #{users_to_add.map { |u| u.uid }}"

      # Users already on the site with the right role do not need to be added again
      users_missing = []
      load_users_page course
      sleep 4
      if paragraph_element(xpath: '//p[contains(.,"No people found")]').exists?
        users_missing = users_to_add
      else
        users_to_add.each do |user|
          user == users_to_add.first ? tries ||= 10 : tries ||= 1
          begin
            scroll_to_bottom
            wait_until(1) { cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]//td[contains(.,'#{user.role}')]").exists? }
          rescue
            (tries -= 1).zero? ? (users_missing << user) : retry
          end
        end
      end
      logger.info "Users who need to be added are #{users_missing.map { |u| u.uid }}"

      # Reactivate inactivated test users and make sure all test users' emails match addresses in test data
      activate_user_and_reset_email users_missing

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
            wait_for_element_and_select_js(user_section_element, section.sis_id) if section
            wait_for_update_and_click_js next_button_element
            users_ready_to_add_msg_element.when_visible Utils.medium_wait
            hide_canvas_footer_and_popup
            wait_for_update_and_click_js next_button_element
            wait_for_users users_with_role
            users_with_role.each { |u| add_event(event, EventType::CREATE, u.full_name) }
          rescue => e
            logger.error "#{e.message}\n#{e.backtrace}"
            logger.warn 'Add User failed, retrying'
            (tries -= 1).zero? ? fail : retry
          end
        end
      end
    end

    # Removes users from a course site
    # @param course [Course]
    # @param users [Array<User>]
    # @param event [Event]
    def remove_users_from_course(course, users, event = nil)
      load_users_page course
      hide_canvas_footer_and_popup
      wait_for_users users
      users.each do |user|
        logger.info "Removing #{user.role} UID #{user.uid} from course site ID #{course.site_id}"
        wait_for_update_and_click link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[contains(@class,'al-trigger')]")
        confirm(true) { wait_for_update_and_click_js link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[@data-event='removeFromCourse']") }
        remove_user_success_element.when_visible Utils.short_wait
        add_event(event, EventType::MODIFY, '"state": "deleted"')
        add_event(event, EventType::MODIFY, user.full_name)
      end
    end

    # Searches for a user by Canvas user ID
    # @param user [User]
    def search_user_by_canvas_id(user)
      wait_for_element_and_type(search_user_input_element, user.canvas_id)
      sleep 1
    end

    # Changes users' Canvas email addresses to the email defined for each in test data. This enables SuiteC email testing.
    # Also reactivates test user accounts that have been deactivated.
    # @param test_users [Array<User>]
    def activate_user_and_reset_email(test_users)
      test_users.each do |user|
        navigate_to "#{Utils.canvas_base_url}/users/#{user.canvas_id}"
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
        user_login_element.when_visible Utils.short_wait
        if user_login.include? 'inactive'
          logger.info "Reactivating UID #{user.uid}"
          wait_for_update_and_click edit_user_login_link_element
          wait_for_element_and_type(user_login_input_element, user.uid)
          wait_for_update_and_click update_user_login_button_element
          wait_until(Utils.short_wait) { user_login == "#{user.uid}" }
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

    # Returns the text in the table cell containing a user's last activity. If multiple sections exist, the text is repeated
    # in separate divs in the cell, so returns the text in the first div.
    # @param uid [Integer]
    # @return [String]
    def roster_user_last_activity(uid)
      path = "//tr[contains(.,'#{uid}')]/td[7]"
      (cell = cell_element(xpath: path)).when_visible Utils.short_wait
      (div = div_element(xpath: "#{path}/div")).exists? ? div.text : cell.text
    end

    # Clicks the Canvas Add People button followed by the Find a Person to Add button and switches to the LTI tool
    # @param driver [Selenium::WebDriver]
    def click_find_person_to_add(driver)
      logger.debug 'Clicking Find a Person to Add button'
      wait_for_load_and_click add_people_button_element
      wait_for_load_and_click find_person_to_add_link_element
      switch_to_canvas_iframe(driver, JunctionUtils.junction_base_url)
    end

    # Returns the number of users in a course site with a given set of roles, optionally using a non-default Canvas base URL
    # @param course [Course]
    # @param roles [Array<String>]
    # @return [Array<Hash>]
    def enrollment_count_by_roles(course, roles, canvas_base_url = nil)
      load_users_page(course, canvas_base_url)
      wait_for_load_and_click enrollment_roles_element
      roles.map do |role|
        role_option = enrollment_roles_options.find { |option| option.include? role }
        count = role_option.delete("#{role} ()").to_i
        logger.debug "The count of #{role} users is currently #{count}"
        {:role => role, :count => count}
      end
    end

    # Waits for a course site's enrollment to finish updating for a given set of user roles and then returns the final count for each role
    # @param course [Course]
    # @param roles [Array<String>]
    # @return [Array<Integer>]
    def wait_for_enrollment_import(course, roles)
      current_count = enrollment_count_by_roles(course, roles)
      begin
        starting_count = current_count
        sleep 20
        current_count = enrollment_count_by_roles(course, roles)
      end while current_count != starting_count
      current_count
    end

    elements(:user_row, :row, xpath: '//table[contains(@class, "roster")]/tbody/tr')
    elements(:student_enrollment_row, :row, :xpath => '//table[contains(@class, "roster")]/tbody/tr[contains(@class, "StudentEnrollment")]')
    elements(:waitlist_enrollment_row, :row, :xpath => '//table[contains(@class, "roster")]/tbody/tr[contains(@class, "Waitlist")]')

    # Determines the number of enrolled and waitlisted students on a course site and scrolls down on the users page until all have loaded. Optionally uses a non-default Canvas base URL.
    # @param course [Course]
    # @param canvas_base_url [String]
    # @return [Integer]
    def load_all_students(course, canvas_base_url = nil)
      counts = enrollment_count_by_roles(course, ['Student', 'Waitlist Student'], canvas_base_url)
      total_count = counts[0][:count] + counts[1][:count]
      logger.debug "Trying to load #{total_count} students and wait list students"
      wait_until(Utils.short_wait) { user_row_elements.any? }
      initial_count = user_row_elements.length
      if initial_count >= total_count
        logger.debug 'All users are currently visible'
      else
        begin
          tries ||= Utils.canvas_enrollment_retries
          new_initial_count = user_row_elements.length
          logger.debug "There are now #{new_initial_count} user rows"
          scroll_to_bottom
          wait_until(Utils.short_wait) { user_row_elements.length > new_initial_count }
          wait_until(Utils.click_wait) { (student_enrollment_row_elements.length + waitlist_enrollment_row_elements.length) == total_count }
        rescue
          (tries -= 1).zero? ? fail : retry
        end
      end
      total_count
    end

    # Returns all the users on a course site section with a Student role
    # @param course [Course]
    # @param section [Section]
    # @return [Array<User>]
    def get_enrolled_students(course, section)
      # Load the users page and scroll until all students are visible on the page.
      load_all_students course

      # Get an array of student users in the with all IDs
      students = student_enrollment_row_elements.map do |row|
        if row.text.include? "#{section.course} #{section.label}"
          canvas_id = row.attribute('id').delete('user_')
          uid = cell_element(xpath: "//table[contains(@class, 'roster')]//tr[contains(@id,'user_#{canvas_id}')]//td[3]").text.strip
          logger.debug "Canvas ID #{canvas_id}, UID #{uid}"
          User.new({uid: uid, canvas_id: canvas_id})
        end
      end
      students.compact
    end

    # SIS IMPORTS

    text_area(:file_input, name: 'attachment')
    button(:upload_button, xpath: '//button[contains(.,"Process Data")]')
    div(:import_success_msg, xpath: '//div[contains(.,"The import is complete and all records were successfully imported.")]')

    # Uploads CSVs on the SIS Import page
    # @param files [Array<String>]
    # @param users [Array<User>]
    # @param event [Event]
    def upload_sis_imports(files, users, event = nil)
      files.each do |csv|
        logger.info "Uploading a SIS import CSV at #{csv}"
        navigate_to "#{Utils.canvas_base_url}/accounts/#{Utils.canvas_uc_berkeley_sub_account}/sis_import"
        file_input_element.when_visible Utils.short_wait
        file_input_element.send_keys csv
        wait_for_update_and_click upload_button_element
        import_success_msg_element.when_present Utils.medium_wait
      end
      users.each do |u|
        (u.status == 'active') ?
            add_event(event, EventType::CREATE, u.full_name) :
            add_event(event, EventType::MODIFY, u.full_name)
      end
    end

    # LTI TOOLS

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
    # @param tool [LtiTools]
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
      hide_canvas_footer_and_popup
    end

    # Enables an LTI tool that is already installed
    # @param course [Course]
    # @param tool [LtiTools]
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
    # @param tool [LtiTools]
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

    # Adds an LTI tool to a course site. If the tool is installed and enabled, skips it. If the tool is installed by disabled, enables
    # it. Otherwise, installs and enables it.
    # @param course [Course]
    # @param tool [LtiTools]
    # @param base_url [String]
    # @param key [String]
    # @param secret [String]
    def add_lti_tool(course, tool, base_url, key, secret)
      logger.info "Adding and/or enabling #{tool.name}"
      load_tools_config_page course
      wait_for_update_and_click navigation_link_element
      hide_canvas_footer_and_popup
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
          self.key_input = key
          self.secret_input = secret
          self.url_input = "#{base_url}#{tool.xml}"
          submit_button
          link_element(xpath: "//td[@title='#{tool.name}']").when_present Utils.medium_wait
          enable_tool(course, tool)
        end
      end
    end

    # Adds a SuiteC LTI tool to a course site
    # @param course [Course]
    # @param tool [LtiTools]
    def add_suite_c_tool(course, tool)
      add_lti_tool(course, tool, SuiteCUtils.suite_c_base_url, SuiteCUtils.lti_credentials[:key], SuiteCUtils.lti_credentials[:secret])
    end

    # Adds the Student Privacy Dashboard tool to a course site
    # @param course [Course]
    def add_privacy_dashboard(course)
      add_lti_tool(course, LtiTools::PRIVACY_DASHBOARD, LRSUtils.base_url, LRSUtils.lti_credentials[:key], LRSUtils.lrs_db_credentials[:secret])
    end

    # Clicks the navigation link for a tool and returns the tool's URL. Optionally records an analytics event.
    # @param driver [Selenium::WebDriver]
    # @param tool [LtiTools]
    # @param event [Event]
    # @return [String]
    def click_tool_link(driver, tool, event = nil)
      driver.switch_to.default_content
      hide_canvas_footer_and_popup
      wait_for_update_and_click_js tool_nav_link(tool)
      wait_until(Utils.medium_wait) { title == "#{tool.name}" }
      logger.info "#{tool.name} URL is #{url = current_url}"
      add_event(event, EventType::NAVIGATE)
      add_event(event, EventType::VIEW)
      case tool
        when LtiTools::ASSET_LIBRARY
          add_event(event, EventType::LAUNCH_ASSET_LIBRARY)
          add_event(event, EventType::LIST_ASSETS)
        when LtiTools::ENGAGEMENT_INDEX
          add_event(event, EventType::LAUNCH_ENGAGEMENT_INDEX)
          add_event(event, EventType::GET_ENGAGEMENT_INDEX)
        when LtiTools::WHITEBOARDS
          add_event(event, EventType::LAUNCH_WHITEBOARDS)
          add_event(event, EventType::LIST_WHITEBOARDS)
        when LtiTools::IMPACT_STUDIO
          add_event(event, EventType::LAUNCH_IMPACT_STUDIO)
        else
          logger.warn "Cannot add an event for '#{tool.name}'"
      end
      url.delete '#'
    end

    checkbox(:hide_grade_distrib_cbx, id: 'course_hide_distribution_graphs')

    # Returns whether or not the 'Hide grade distribution graphs from students' option is selected on a course site
    # @param course [Course]
    # @return [boolean]
    def grade_distribution_hidden?(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
      wait_for_load_and_click link_element(text: 'more options')
      hide_grade_distrib_cbx_element.when_visible Utils.short_wait
      hide_grade_distrib_cbx_checked?
    end

    # MESSAGES

    text_area(:message_addressee, name: 'recipients[]')
    text_area(:message_input, name: 'body')

  end
end
