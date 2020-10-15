require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasCreateCourseSitePage < CanvasSiteCreationPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      button(:maintenance_button, xpath: '//button[contains(@class, "bc-template-canvas-maintenance-notice-button")]')
      div(:maintenance_notice, class: 'bc-template-canvas-maintenance-notice-details')
      link(:bcourses_service, xpath: '//a[contains(text(),"bCourses service page")]')
      button(:need_help, xpath: '//button[contains(.,"Need help deciding which official sections to select")]')
      div(:help, id: 'section-selection-help')
      link(:instr_mode_link, xpath: '//a[contains(text(), "Learn more about instruction modes in bCourses.")]')

      div(:progress_bar, xpath: '//div[@role="progressbar"]')

      button(:switch_mode, xpath: '//button[contains(@class, "bc-page-create-course-site-admin-mode-switch")]')

      button(:switch_to_instructor, xpath: '//button[contains(.,"Switch to acting as instructor")]')
      button(:as_instructor_button, id: 'sections-by-uid-button')
      text_area(:instructor_uid, id: 'instructor-uid')

      button(:switch_to_ccn, xpath: '//button[contains(.,"Switch to CCN input")]')
      button(:review_ccns_button, xpath: '//button[contains(text(), "Review matching CCNs")]')
      text_area(:ccn_list, id: 'bc-page-create-course-site-ccn-list')

      button(:next_button, xpath: '//button[contains(text(), "Next")]')
      button(:cancel_button, xpath: '//button[contains(text(), "Cancel")]')

      text_area(:site_name_input, id: 'siteName')
      text_area(:site_abbreviation, id: 'siteAbbreviation')
      div(:site_name_error, xpath: '//div[contains(.,"Please fill out a site name.")]')
      div(:site_abbreviation_error, xpath: '//div[contains(.,"Please fill out a site abbreviation.")]')

      button(:create_site_button, xpath: '//button[contains(text(), "Create Course Site")]')
      button(:go_back_button, xpath: '//button[contains(text(), "Go Back")]')

      paragraph(:no_access_msg, xpath: '//p[text()="This feature is only available to faculty and staff."]')

      # Clicks the button for the test course's term. Uses JavaScript rather than WebDriver
      # @param course [Course]
      def choose_term(course)
        button_element(xpath: "//label[contains(.,'#{course.term}')]/..").when_visible Utils.long_wait
        wait_for_update_and_click button_element(xpath: "//label[contains(.,'#{course.term}')]/..")
      end

      # Searches for a course by instructor UID, by section ID list, or by neither depending on the workflow associated
      # with the test course.
      # @param course [Course]
      # @param instructor [User]
      # @param sections [Array<Section>]
      def search_for_course(course, instructor, sections=nil)
        logger.debug "Searching for #{course.code} in #{course.term}"
        if course.create_site_workflow == 'uid'
          logger.debug "Searching by instructor UID #{instructor.uid}"
          switch_mode unless switch_to_ccn?
          wait_for_element_and_type(instructor_uid_element, instructor.uid)
          wait_for_update_and_click as_instructor_button_element
          choose_term course
        elsif course.create_site_workflow == 'ccn'
          logger.debug 'Searching by CCN list'
          switch_mode unless switch_to_instructor?
          choose_term course
          sleep 1
          ccn_list = sections.map &:id
          logger.debug "CCN list is '#{ccn_list}'"
          wait_for_element_and_type(ccn_list_element, ccn_list.join(', '))
          wait_for_update_and_click review_ccns_button_element
        else
          logger.debug 'Searching as the instructor'
          choose_term course
        end
      end

      # Clicks the 'need help' button
      def click_need_help
        button_element(xpath: '//button[contains(.,"Need help deciding which official sections to select")]').click
      end

      # Given a section ID, returns a hash of section data displayed on that row
      # @param section_id [String]
      # @return [Hash]
      def section_data(section_id)
        {
          code: section_course_code(section_id),
          label: section_label(section_id),
          id: section_id,
          schedules: section_schedules(section_id),
          locations: section_locations(section_id),
          instructors: section_instructors(section_id)
        }
      end

      # Given an array of sections, selects the corresponding rows
      # @param sections [Array<Section>]
      def select_sections(sections)
        sections.each do |section|
          logger.debug "Selecting section ID #{section.id}"
          section_checkbox(section.id).when_present Utils.short_wait
          js_click section_checkbox(section.id) unless section_checkbox(section.id).selected?
        end
      end

      def section_cbx_xpath(section_id)
        "//input[@value='#{section_id}']"
      end

      # Returns the checkbox for a given section
      # @param section_id [String]
      # @return [PageObject::Elements::CheckBox]
      def section_checkbox(section_id)
        checkbox_element(xpath: section_cbx_xpath(section_id))
      end

      # Returns the course code for a section
      # @param section_id [String]
      def section_course_code(section_id)
        div_element(xpath: "#{section_cbx_xpath(section_id)}/ancestor::tbody//td[contains(@class, 'course-code')]/div").text.strip
      end

      # Returns the label for a section
      # @param section_id [String]
      # @return [String]
      def section_label(section_id)
        label_element(xpath: "(//label[@for='cc-template-canvas-manage-sections-checkbox-#{section_id}'])[2]").text.strip
      end

      # Returns the schedules for a section
      # @param section_id [String]
      # @return [String]
      def section_schedules(section_id)
        if (e = div_element(xpath: "#{section_cbx_xpath(section_id)}/../ancestor::tbody//td[contains(@class, 'section-timestamps')]")).exists?
          e.attribute('innerText')
        else
          ''
        end
      end

      # Returns the locations for a section
      # @param section_id [String]
      # @return [String]
      def section_locations(section_id)
        if (e = div_element(xpath: "#{section_cbx_xpath(section_id)}/../ancestor::tbody//td[contains(@class, 'section-locations')]")).exists?
          e.attribute('innerText')
        else
          ''
        end
      end

      # Returns the instructor names for a section
      # @param section_id [String]
      # @return [String]
      def section_instructors(section_id)
        if (e = div_element(xpath: "#{section_cbx_xpath(section_id)}/../ancestor::tbody//td[contains(@class, 'section-instructors')]/div")).exists?
          e.text
        else
          ''
        end
      end

      # Returns the section IDs displayed under a course
      # @param course [Course]
      # @return [Array<String>]
      def course_section_ids(course)
        cell_elements(xpath: "//li[contains(., \"#{course.code}: #{course.title}\")]//tbody/tr/td[4]").map &:text
      end

      # Clicks the 'next' button once it is enabled
      def click_next
        wait_until(Utils.short_wait) { !next_button_element.attribute('disabled') }
        wait_for_update_and_click next_button_element
        site_name_input_element.when_visible Utils.medium_wait
      end

      def click_cancel
        logger.debug 'Clicking cancel button'
        wait_for_update_and_click cancel_button_element
      end

      # Enters a unique course site name and abbreviation and returns the abbreviation
      # @param course [Course]
      # @return [String]
      def enter_site_titles(course)
        site_abbreviation = "QA bCourses Test #{Utils.get_test_id}"
        wait_for_element_and_type(site_name_input_element, "#{site_abbreviation} - #{course.code}")
        wait_for_element_and_type(site_abbreviation_element, site_abbreviation)
        site_abbreviation
      end

      # Clicks the final create site button
      def click_create_site
        wait_for_update_and_click create_site_button_element
      end

      def click_go_back
        logger.debug 'Clicking go-back button'
        wait_for_update_and_click go_back_button_element
      end

      # Waits for a newly created course site to load, sets the site ID for a course, and then writes the site ID to the
      # Junction test data file for use in further tests.
      # @param course [Course]
      def wait_for_site_id(course)
        wait_until(Utils.long_wait) { current_url.include? "#{Utils.canvas_base_url}/courses" }
        course.site_id = current_url.delete "#{Utils.canvas_base_url}/courses/"
        logger.info "Course site ID is #{course.site_id}"
        JunctionUtils.set_junction_test_course_id course
      end

      def wait_for_progress_bar
        progress_bar_element.when_visible Utils.medium_wait
        logger.info 'Waiting for progress bar to complete'
        progress_bar_element.when_not_visible Utils.long_wait
      end

      def wait_for_standalone_site_id(course, user, splash_page)
        wait_for_progress_bar
        course.create_site_workflow = 'self'
        tries = Utils.short_wait
        begin
          JunctionUtils.clear_cache(@driver, splash_page)
          splash_page.basic_auth user.uid
          load_standalone_tool
          click_create_course_site
          search_for_course(course, user)
          expand_available_sections course.code
          link = link_element(xpath: "//a[contains(text(), '#{course.title}')]")
          course.site_id = link.attribute('href').gsub("#{Utils.canvas_base_url}/courses/", '')
          logger.info "Course site ID is #{course.site_id}"
          JunctionUtils.set_junction_test_course_id course
        rescue => e
          Utils.log_error e
          logger.warn "UID #{user.uid} is not yet associated with the site"
          if (tries -= 1).zero?
            fail
          else
            sleep Utils.short_wait
            retry
          end
        end
      end

      # Combines methods to search for a course, select sections, and create a new site
      # @param course [Course]
      # @param user [User]
      # @param sections [Array<Section>]
      def provision_course_site(course, user, sections, opts={})
        opts[:standalone] ? load_standalone_tool : load_embedded_tool(user)
        click_create_course_site
        course.create_site_workflow = opts[:admin] ? 'ccn' : nil
        search_for_course(course, user, sections)
        expand_available_sections course.code
        select_sections sections
        click_next
        course.title = enter_site_titles course
        click_create_site
        wait_for_site_id(course) unless opts[:standalone]
      end

    end
  end
end
