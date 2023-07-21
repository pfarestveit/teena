require_relative '../../util/spec_helper'

module Page

  class CanvasPage

    include PageObject
    include Logging
    include Page
    include CanvasPeoplePage

    button(:hamburger_button, xpath: '//button[contains(@class, "mobile-header-hamburger")]')

    h2(:updated_terms_heading, xpath: '//h2[contains(text(),"Updated Terms of Use")]')
    checkbox(:terms_cbx, name: 'user[terms_of_use]')
    button(:accept_course_invite, name: 'accept')
    link(:masquerade_link, xpath: '//a[contains(@href, "masquerade")]')
    link(:stop_masquerading_link, class: 'stop_masquerading')
    h2(:recent_activity_heading, xpath: '//h2[contains(text(),"Recent Activity")]')
    h3(:project_site_heading, xpath: '//h3[text()="Is bCourses Right For My Project?"]')

    link(:about_link, text: 'About')
    link(:accessibility_link, text: 'Accessibility')
    link(:nondiscrimination_link, text: 'Nondiscrimination')
    link(:privacy_policy_link, text: 'Privacy Policy')
    link(:terms_of_service_link, text: 'Terms of Service')
    link(:data_use_link, text: 'Data Use & Analytics')
    link(:honor_code_link, text: 'UC Berkeley Honor Code')
    link(:student_resources_link, text: 'Student Resources')
    link(:user_prov_link, text: 'User Provisioning')
    link(:conf_tool_link, text: 'BigBlueButton')

    button(:submit_button, xpath: '//button[contains(.,"Submit")]')
    button(:save_button, xpath: '//button[text()="Save"]')
    button(:update_course_button, xpath: '//button[contains(.,"Update Course Details")]')
    li(:update_course_success, xpath: '//*[contains(.,"successfully updated")]')
    form(:profile_form, xpath: '//form[@action="/logout"]')
    link(:profile_link, id: 'global_nav_profile_link')
    button(:logout_link, xpath: '//button[contains(.,"Logout")]')
    link(:policies_link, id: 'global_nav_academic_policies_link')
    link(:policies_responsive_link, id: 'global_nav_academic_policies_link_responsive')
    link(:mental_health_link, id: 'global_nav_mental_health_resources_link')
    link(:mental_health_responsive_link, id: 'global_nav_mental_health_resources_link_responsive')

    h1(:unexpected_error_msg, xpath: '//h1[contains(text(),"Unexpected Error")]')
    h2(:unauthorized_msg, xpath: '//h2[contains(text(),"Unauthorized")]')
    h1(:access_denied_msg, xpath: '//h1[text()="Access Denied"]')
    div(:flash_msg, xpath: '//div[@class="flashalert-message"]')

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
      profile_link_element.when_present Utils.short_wait
    end

    # Shifts to default content, logs out, and waits for CalNet logout confirmation
    # @param cal_net [Page::CalNetPage]
    def log_out(cal_net)
      @driver.switch_to.default_content
      wait_for_load_and_click_js profile_link_element
      sleep 1
      wait_for_update_and_click_js profile_form_element
      wait_for_update_and_click_js logout_link_element if logout_link_element.exists?
      cal_net.username_element.when_visible Utils.short_wait
    end

    def masquerade_as(user, course = nil)
      load_homepage
      sleep 2
      stop_masquerading if stop_masquerading_link?
      logger.info "Masquerading as #{user.role} UID #{user.uid}, Canvas ID #{user.canvas_id}"
      navigate_to "#{Utils.canvas_base_url}/users/#{user.canvas_id}/masquerade"
      wait_for_load_and_click masquerade_link_element
      stop_masquerading_link_element.when_visible Utils.short_wait
      load_course_site course unless course.nil?
    end

    # Quits masquerading as another user
    def stop_masquerading
      logger.debug 'Ending masquerade'
      load_homepage unless stop_masquerading_link?
      wait_for_load_and_click stop_masquerading_link_element
      stop_masquerading_link_element.when_not_visible(Utils.medium_wait) rescue Selenium::WebDriver::Error::StaleElementReferenceError
    end

    # Loads a given sub-account page
    def load_sub_account(sub_account)
      logger.debug "Loading sub-account #{sub_account}"
      navigate_to "#{Utils.canvas_base_url}/accounts/#{sub_account}"
    end

    def expand_mobile_menu
      logger.info 'Clicking the hamburger to reveal the menu'
      wait_for_update_and_click_js hamburger_button_element
    end

    def click_user_prov
      logger.info 'Clicking the link to the User Provisioning tool'
      wait_for_load_and_click user_prov_link_element
      switch_to_canvas_iframe
    end

    # Clicks the 'save and publish' button using JavaScript rather than WebDriver
    def click_save_and_publish
      scroll_to_bottom
      wait_for_update_and_click_js save_and_publish_button_element
    end

    def wait_for_flash_msg(text, wait)
      flash_msg_element.when_visible wait
      wait_until(1) { flash_msg.include? text }
    end

    def wait_for_error(canvas_msg_el, junction_msg_el)
      tries ||= Utils.short_wait
      wait_until(2) do
        (switch_to_main_content; canvas_msg_el.exists?) || (switch_to_canvas_iframe; junction_msg_el.exists?)
      end
    rescue
      if (tries -= 1).zero?
        fail("Found neither Canvas nor Junction error")
      else
        retry
      end
    ensure
      switch_to_main_content
    end

    # COURSE SITE SETUP

    link(:create_site_link, xpath: '//a[contains(text(),"Create a Site")]')
    link(:create_site_settings_link, xpath: '//div[contains(@class, "profile-tray")]//a[contains(text(),"Create a Site")]')

    button(:add_new_course_button, xpath: '//button[@aria-label="Create new course"]')
    text_area(:course_name_input, xpath: '(//form[@aria-label="Add a New Course"]//input)[1]')
    text_area(:ref_code_input, xpath: '(//form[@aria-label="Add a New Course"]//input)[2]')
    select_list(:term, id: 'course_enrollment_term_id')
    button(:create_course_button, xpath: '//button[contains(.,"Add Course")]')

    span(:course_site_heading, xpath: '//li[contains(@id,"crumb_course_")]//span')
    text_area(:search_course_input, xpath: '//input[@placeholder="Search courses..."]')
    button(:search_course_button, xpath: '//input[@id="course_name"]/following-sibling::button')
    paragraph(:add_course_success, xpath: '//p[contains(.,"successfully added!")]')

    link(:course_details_link, text: 'Course Details')
    text_area(:course_title, id: 'course_name')
    text_area(:course_code, id: 'course_course_code')
    list_item(:course_site_sidebar_tab, id: 'section-tabs')

    link(:copy_course_link, xpath: '//a[contains(@class, "copy_course_link")]')
    button(:copy_course_create_button, xpath: '//button[text()="Create Course"]')
    span(:copy_course_success_msg, xpath: '//span[text()="Completed"]')

    def click_create_site_settings_link
      wait_for_update_and_click_js profile_link_element
      sleep 1
      wait_for_update_and_click_js profile_form_element
      wait_for_update_and_click create_site_settings_link_element
      switch_to_canvas_iframe
    end

    def create_site(site)
      wait_for_load_and_click add_new_course_button_element
      course_name_input_element.when_visible Utils.short_wait
      wait_for_element_and_type(course_name_input_element, "#{site.title}")
      wait_for_element_and_type(ref_code_input_element, "#{site.abbreviation}")
      wait_for_update_and_click create_course_button_element
      add_course_success_element.when_visible Utils.medium_wait
    end

    def create_squiggy_course_site(test)
      if test.course_site.site_id
        navigate_to "#{Utils.canvas_base_url}/courses/#{test.course_site.site_id}/settings"
        course_details_link_element.when_visible Utils.medium_wait
        test.course_site.title = course_title
        test.course_site.abbreviation = course_code
      else
        SquiggyUtils.inactivate_all_courses
        logger.info "Creating a Squiggy course site named #{test.course_site.title}"
        if SquiggyUtils.template_course_id
          begin
            template_site = SquiggySite.new site_id: SquiggyUtils.template_course_id
            load_course_settings template_site
            wait_for_load_and_click copy_course_link_element
            wait_for_element_and_type(course_title_element, test.course_site.title)
            wait_for_element_and_type(course_code_element, test.course_site.abbreviation)
            wait_for_update_and_click copy_course_create_button_element
            copy_course_success_msg_element.when_present Utils.medium_wait
            test.course_site.is_copy = true
          rescue => e
            logger.error e.message
            load_sub_account Utils.canvas_qa_sub_account
            create_site test.course_site
          end
        else
          load_sub_account Utils.canvas_qa_sub_account
          create_site test.course_site
        end
        test.course_site.site_id = search_for_site(test.course_site, Utils.canvas_qa_sub_account)
        logger.info "Course site ID is #{test.course_site.site_id}"
        if test.course_site.sections&.any?
          add_sections(test.course_site, test.course_site.sections)
          add_users_by_section(test.course_site, test.course_site.manual_members)
        else
          add_users(test.course_site, test.course_site.manual_members)
        end
        remove_users_from_course(test.course_site, [test.admin])
        publish_course_site test.course_site
        add_squiggy_tools test
      end
    end

    def create_generic_course_site(sub_account, course, test_users, test_id)
      if course.site_id.nil?
        load_sub_account sub_account
        wait_for_load_and_click add_new_course_button_element
        course_name_input_element.when_visible Utils.short_wait
        course.title = "QA Test - #{Time.at test_id.to_i}" if course.title.nil?
        course.abbreviation = "QA #{Time.at test_id.to_i} LEC001" if course.abbreviation.nil?
        wait_for_element_and_type(course_name_input_element, "#{course.title}")
        wait_for_element_and_type(ref_code_input_element, "#{course.abbreviation}")
        logger.info "Creating a course site named #{course.title} in #{course.term} semester"
        wait_for_update_and_click create_course_button_element
        add_course_success_element.when_visible Utils.medium_wait
        course.site_id = search_for_site(course, sub_account)
        unless course.term.nil?
          navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
          wait_for_element_and_select(term_element, course.term)
          wait_for_update_and_click_js update_course_button_element
          update_course_success_element.when_visible Utils.medium_wait
        end
      else
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
        course_details_link_element.when_visible Utils.medium_wait
        course.title = course_title
        course.abbreviation = course_code
      end
      publish_course_site course
      logger.info "Course ID is #{course.site_id}"
      add_users(course, test_users)
    end

    def create_ripley_mailing_list_site(site)
      if site.site_id
        navigate_to "#{Utils.canvas_base_url}/courses/#{site.site_id}/settings"
        course_details_link_element.when_visible Utils.medium_wait
        site.course.title = course_title
        site.course.code = course_code
      else
        load_sub_account RipleyTool::MAILING_LIST.account
        logger.info "Creating a course site named #{site.title}#{' in ' + site.term.name if site.term}"
        create_site site
        site.site_id = search_for_site(site, RipleyTool::MAILING_LIST.account)
        if site.term
          navigate_to "#{Utils.canvas_base_url}/courses/#{site.site_id}/settings"
          wait_for_element_and_select(term_element, site.term.name)
          wait_for_update_and_click_js update_course_button_element
          update_course_success_element.when_visible Utils.medium_wait
        end
      end
      publish_course_site site
      logger.info "Course ID is #{site.site_id}"
      add_users(site, site.manual_members)
    end

    def click_create_site
      tries ||= 2
      wait_for_load_and_click create_site_link_element
    rescue
      execute_script('arguments[0].style.hidden="hidden";', div_element(id: 'fixed_bottom'))
      retry unless (tries -= 1).zero?
    ensure
      switch_to_canvas_iframe JunctionUtils.junction_base_url
    end

    def accept_invite
      logger.info 'Accepting course invite'
      accept_course_invite
      accept_course_invite_element.when_not_visible Utils.medium_wait
    end

    # Loads a course site and handles prompts that can appear
    # @param course [Course]
    def load_course_site(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}"
      wait_until(Utils.medium_wait) { current_url.include? "#{course.site_id}" }
      course_site_sidebar_tab_element.when_present Utils.short_wait
      if updated_terms_heading?
        logger.info 'Accepting terms and conditions'
        terms_cbx_element.when_visible Utils.short_wait
        check_terms_cbx
        submit_button
      end
      div_element(id: 'content').when_present Utils.medium_wait
      sleep 1
      if accept_course_invite?
        accept_invite
        sleep 1
        flash_msg_element.when_not_present Utils.short_wait
      end
    end

    def search_for_site(site, sub_account)
      tries ||= 6
      logger.info "Searching for '#{site.title}'"
      load_sub_account sub_account
      wait_for_element_and_type(search_course_input_element, "#{site.title}")
      sleep 1
      wait_for_update_and_click link_element(text: "#{site.title}")
      publish_button_element.when_present Utils.short_wait
      current_url.sub("#{Utils.canvas_base_url}/courses/", '')
    rescue
      logger.error('Course site not found, retrying')
      sleep Utils.short_wait
      (tries -= 1).zero? ? fail : retry
    end

    link(:course_details_tab, xpath: '//a[contains(.,"Course Details")]')
    text_area(:course_sis_id, id: 'course_sis_source_id')
    link(:sections_tab, xpath: '//a[contains(@href,"#tab-sections")]')
    elements(:section_data, :span, xpath: '//li[@class="section"]/span[@class="users_count"]')
    text_area(:section_name, id: 'course_section_name')
    button(:add_section_button, xpath: '//button[@title="Add Section"]')
    link(:edit_section_link, class: 'edit_section_link')
    text_area(:section_sis_id, id: 'course_section_sis_source_id')
    button(:update_section_button, xpath: '//button[contains(.,"Update Section")]')

    # Obtains the Canvas SIS ID for the course site
    # @param course [Course]
    # @return [String]
    def set_course_sis_id(course)
      load_course_settings course
      course_sis_id_element.when_visible Utils.short_wait
      course.sis_id = course_sis_id_element.attribute('value')
      logger.debug "Course SIS ID is #{course.sis_id}"
      course.sis_id
    end

    # Obtains the Canvas SIS IDs for the sections on the course site
    # @param course [Course]
    def set_section_sis_ids(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings#tab-sections"
      wait_for_load_and_click sections_tab_element
      wait_until(Utils.short_wait) { section_data_elements.any? }
      sis_ids = section_data_elements.map do |el|
        el.when_visible(Utils.short_wait)
        el.text.split[-2]
      end
      course.sections.each do |section|
        section.sis_id = sis_ids.find { |id| id.include? section.id }
      end
    end

    def add_section(site, section)
      logger.info "Adding section #{section.sis_id}"
      load_course_settings site
      wait_for_update_and_click_js sections_tab_element
      wait_for_element_and_type(section_name_element, section.sis_id)
      wait_for_update_and_click add_section_button_element
      # Add SIS id to section
      wait_for_load_and_click link_element(text: section.sis_id)
      wait_for_load_and_click edit_section_link_element
      wait_for_element_and_type(section_sis_id_element, section.sis_id)
      wait_for_update_and_click update_section_button_element
      update_section_button_element.when_not_visible Utils.medium_wait
    end

    def add_sections(site, sections)
      sections.each { |s| add_section(site, s) }
    end

    # Adds a section to a course site and assigns SIS IDs to both the course and the section
    # @param course [Course]
    # @param section [Section]
    def add_sis_section_and_ids(course, section)
      # Add SIS id to course
      load_course_settings course
      wait_for_load_and_click course_details_tab_element
      wait_for_element_and_type(course_sis_id_element, course.sis_id)
      wait_for_update_and_click update_course_button_element
      update_course_success_element.when_visible Utils.short_wait
      # Add unique section
      add_section(course, section)
    end

    div(:publish_div, id: 'course_status_actions')
    button(:publish_button, class: 'btn-publish')
    button(:save_and_publish_button, class: 'save_and_publish')
    button(:published_button, class: 'btn-published')
    form(:published_status, id: 'course_status_form')
    radio_button(:activity_stream_radio, xpath: '//span[contains(.,"Course Activity Stream")]/ancestor::label')
    button(:choose_and_publish_button, xpath: '//span[contains(.,"Choose and Publish")]/ancestor::button')

    # Publishes a course site
    # @param course [Course]
    def publish_course_site(course)
      logger.info 'Publishing the course'
      load_course_site course
      published_status_element.when_visible Utils.short_wait
      if published_button?
        logger.debug 'The site is already published'
      else
        logger.debug 'The site is unpublished, publishing'
        js_click publish_button_element
        unless course.create_site_workflow || course.is_copy
          wait_for_update_and_click activity_stream_radio_element
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
      list_item_element(xpath: '//*[contains(.,"Course was successfully updated")]').when_present Utils.short_wait
    end

    # SIS IMPORTS

    text_area(:file_input, name: 'attachment')
    button(:upload_button, xpath: '//button[contains(.,"Process Data")]')
    div(:import_success_msg, xpath: '//div[contains(.,"The import is complete and all records were successfully imported.")]')

    def upload_sis_imports(files)
      files.each do |csv|
        logger.info "Uploading a SIS import CSV at #{csv}"
        navigate_to "#{Utils.canvas_base_url}/accounts/#{Utils.canvas_uc_berkeley_sub_account}/sis_import"
        file_input_element.when_visible Utils.short_wait
        file_input_element.send_keys csv
        wait_for_update_and_click upload_button_element
        import_success_msg_element.when_present Utils.long_wait
      end
    end

    # SETTINGS

    checkbox(:set_grading_scheme_cbx, id: 'course_grading_standard_enabled')

    # Loads the course settings page
    # @param course [Course]
    def load_course_settings(course)
      logger.info "Loading settings page for course ID #{course.site_id}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings#tab-details"
      set_grading_scheme_cbx_element.when_present Utils.medium_wait
    end

    button(:official_sections_notice, xpath: '//button[contains(., "Need Help Adding a Section/Roster?")]')
    link(:official_sections_help_link, xpath: '//a[contains(., "add or delete a course roster from your bCourses site")]')

    def load_course_sections(course)
      logger.info "Loading sections settings page for course ID #{course.site_id}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings#tab-sections"
      official_sections_notice_element.when_present Utils.medium_wait
    end

    def expand_official_sections_notice
      logger.info 'Expanding official sections notice'
      wait_for_update_and_click official_sections_notice_element
    end

    # LTI TOOLS

    link(:apps_link, text: 'Apps')
    link(:navigation_link, text: 'Navigation')
    link(:view_apps_link, text: 'View App Configurations')
    link(:add_app_link, xpath: '//button[contains(., "Add App")]')
    select_list(:config_type, id: 'configuration_type_selector')
    text_area(:app_name_input, xpath: '//div[@class="ConfigurationFormUrl"]/div//input')
    text_area(:key_input, xpath: '(//div[@class="ConfigurationFormUrl"]/div[2]//input)[1]')
    text_area(:secret_input, xpath: '(//div[@class="ConfigurationFormUrl"]/div[2]//input)[2]')
    text_area(:url_input, xpath: '//div[@class="ConfigurationFormUrl"]/div[3]//input')
    text_area(:client_id_input, name: 'client_id')
    button(:add_tool_button, id: 'continue-install')
    link(:app_placements_button, text: 'Placements')
    button(:activate_navigation_button, xpath: '//span[text()="Course Navigation"]/following-sibling::span//button')
    button(:close_placements_button, xpath: '//span[@aria-label="App Placements"]//button[contains(., "Close")]')

    def tool_nav_link(tool)
      link_element(xpath: "//ul[@id='section-tabs']//a[text()='#{tool.name}']")
    end

    # Loads the LTI tool configuration page for a course site
    # @param course [Course]
    def load_tools_config_page(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings/configurations"
    end

    def load_tools_adding_page(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings/configurations#tab-tools"
    end

    # Loads the site navigation page
    # @param course [Course]
    def load_navigation_page(course)
      load_tools_config_page course
      wait_for_update_and_click navigation_link_element
      hide_canvas_footer_and_popup
    end

    def enable_tool(tool, site=nil)
      site ? load_navigation_page(site) : load_sub_account(tool.account)
      wait_for_update_and_click link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a")
      wait_for_update_and_click link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a[@title='Enable this item']")
      list_item_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]").when_visible Utils.medium_wait
      wait_for_update_and_click_js save_button_element
      tool_nav_link(tool).when_visible Utils.medium_wait
    end

    # Disables an LTI tool that is already installed
    # @param course [Course]
    def disable_tool(course, tool)
      logger.info "Disabling #{tool.name}"
      load_navigation_page course
      if verify_block { link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a").when_present 2 }
        logger.debug "#{tool.name} is already installed but disabled, skipping"
      else
        if link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a").exists?
          logger.debug "#{tool.name} is installed and enabled, disabling"
          wait_for_update_and_click link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a")
          wait_for_update_and_click link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a[@title='Disable this item']")
          list_item_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]").when_visible Utils.medium_wait
          save_button
          tool_nav_link(tool).when_not_visible Utils.medium_wait
          pause_for_poller
        else
          logger.debug "#{tool.name} is not installed, skipping"
        end
      end
    end

    def add_squiggy_tools(test)
      unless test.course_site.is_copy
        creds = SquiggyUtils.lti_credentials
        test.course_site.lti_tools.each do |tool|
          logger.info "Adding and/or enabling #{tool.name}"
          load_tools_config_page test.course_site
          wait_for_update_and_click navigation_link_element
          hide_canvas_footer_and_popup
          if verify_block { link_element(xpath: "//ul[@id='nav_enabled_list']/li[contains(.,'#{tool.name}')]//a").when_present 2 }
            logger.debug "#{tool.name} is already installed and enabled, skipping"
          else
            if link_element(xpath: "//ul[@id='nav_disabled_list']/li[contains(.,'#{tool.name}')]//a").exists?
              fail "#{tool.name} is already installed but it shouldn't be"
            else
              logger.debug "#{tool.name} is not installed, installing and enabling"

              # Configure tool
              load_tools_adding_page test.course_site
              wait_for_update_and_click apps_link_element
              wait_for_update_and_click add_app_link_element
              wait_for_element_and_select(config_type_element, 'By URL')
              sleep 1
              wait_for_element_and_type(app_name_input_element, "#{tool.name}")
              wait_for_element_and_type(key_input_element, creds[:key])
              wait_for_element_and_type(secret_input_element, creds[:secret])
              wait_for_element_and_type(url_input_element, "#{SquiggyUtils.base_url}#{tool.xml}")
              wait_for_update_and_click submit_button_element
              wait_for_update_and_click add_tool_button_element
              link_element(xpath: "//td[@title='#{tool.name}']").when_present Utils.medium_wait

              # Enable tool placement in sidebar navigation
              wait_for_update_and_click_js button_element(xpath: "//tr[contains(., '#{tool.name}')]//button")
              wait_for_update_and_click_js app_placements_button_element
              wait_for_update_and_click_js activate_navigation_button_element
              wait_for_update_and_click_js close_placements_button_element
              sleep 1
              enable_tool(tool, test.course_site)
            end
          end
        end
      end
      test.course_site.engagement_index_url = click_tool_link SquiggyTool::ENGAGEMENT_INDEX
      test.course_site.impact_studio_url = click_tool_link SquiggyTool::IMPACT_STUDIO
      test.course_site.whiteboards_url = click_tool_link SquiggyTool::WHITEBOARDS
      test.course_site.asset_library_url = click_tool_link SquiggyTool::ASSET_LIBRARY
      asset_library = SquiggyAssetLibraryListViewPage.new @driver
      canvas_assigns_page = CanvasAssignmentsPage.new @driver
      switch_to_canvas_iframe
      asset_library.ensure_canvas_sync(test, canvas_assigns_page)
    end

    def load_account_apps(account)
      navigate_to "#{Utils.canvas_base_url}/accounts/#{account}/settings/configurations#tab-tools"
      wait_until(Utils.medium_wait) { row_elements(xpath: '//tr[contains(@class, "ExternalToolsTableRow")]').any? }
      hide_canvas_footer_and_popup
    end

    def ripley_tool_installed?(tool)
      logger.info "Checking if Ripley's #{tool.name} is installed"
      load_account_apps tool.account
      verify_block { cell_element(xpath: "//td[text()='#{tool.name}']").when_present Utils.short_wait }
    end

    def get_ripley_tool_dev_key(tool)
      navigate_to "#{Utils.canvas_base_url}/accounts/#{Utils.canvas_uc_berkeley_sub_account}/developer_keys"
      wait_for_load_and_click button_element(xpath: '//button[contains(., "Show All Keys")]')
      el = div_element(xpath: "//td[contains(., '#{tool.name}')]/following-sibling::td[2]/div/div")
      el.when_present Utils.medium_wait
      tool.dev_key = el.text
    end

    def add_ripley_tool(site, tool)
      if ripley_tool_installed? tool
        logger.info "Tool #{tool.name} is already installed"
      else
        logger.info "Tool #{tool.name} is not installed, installing"
        get_ripley_tool_dev_key tool
        load_account_apps tool.account
        wait_for_update_and_click add_app_link_element
        wait_for_element_and_select(config_type_element, 'By Client ID')
        wait_for_element_and_type(client_id_input_element, tool.dev_key)
        wait_for_update_and_click submit_button_element
        wait_for_update_and_click button_element(xpath: '//button[contains(., "Install")]')
        wait_for_update_and_click add_tool_button_element rescue Selenium::WebDriver::Error::TimeoutError
      end
    end

    def click_tool_link(tool)
      switch_to_main_content
      hide_canvas_footer_and_popup
      wait_for_update_and_click_js tool_nav_link(tool)
      wait_until(Utils.medium_wait) { title == "#{tool.name}" }
      logger.info "#{tool.name} URL is #{url = current_url}"
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

    def msg_recipient_el(user)
      span_element(xpath: "//span[text()='#{user.full_name}']")
    end

    # FILES

    link(:files_link, text: 'Files')
    button(:access_toggle, xpath: '//button[@aria-label="Notice to Instructors for Making Course Materials Accessible"]')
    link(:access_basics_link, xpath: '//a[contains(., "Accessibility Basics for bCourses")]')
    link(:access_checker_link, xpath: '//a[contains(., "How do I use the Accessibility Checker")]')
    link(:access_dsp_link, xpath: '//a[contains(., "How to improve the accessibility of your online content")]')
    link(:access_sensus_link, xpath: '//a[contains(., "SensusAccess Conversion")]')
    link(:access_ally_link, xpath: '//a[contains(., "Ally in bCourses Service Page")]')

    def click_files_tab
      logger.info 'Clicking Files tab'
      wait_for_update_and_click files_link_element
    end

    def toggle_access_links
      wait_for_update_and_click access_toggle_element
    end

    # USER ACCOUNTS

    text_field(:user_search_input, xpath: '//input[@placeholder="Search people..."]')

    def user_result_link(user)
      link_element(xpath: "//td[text()=\"#{user.email}\"]/preceding-sibling::th/a")
    end

    def set_canvas_ids(users)
      navigate_to "#{Utils.canvas_base_url}/accounts/#{Utils.canvas_uc_berkeley_sub_account}/users"
      users.each do |user|
        unless user.canvas_id
          wait_for_textbox_and_type(user_search_input_element, user.email)
          user_result_link(user).when_present Utils.medium_wait
          user.canvas_id = user_result_link(user).attribute('href').split('/').last
        end
      end
    end

  end
end
