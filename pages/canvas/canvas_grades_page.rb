require_relative '../../util/spec_helper'

module Page

  class CanvasGradesPage < CanvasPage

    include PageObject
    include Logging
    include Page

    # COURSE LEVEL GRADEBOOK-RELATED SETTINGS

    checkbox(:set_grading_scheme_cbx, id: 'course_grading_standard_enabled')

    # Ensures that no grading scheme is set on a course site
    # @param course [Course]
    def disable_grading_scheme(course)
      logger.info "Making sure grading scheme is disabled for course ID #{course.site_id}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
      set_grading_scheme_cbx_element.when_present Utils.medium_wait
      scroll_to_bottom
      if set_grading_scheme_cbx_checked?
        wait_for_update_and_click set_grading_scheme_cbx_element
        sleep 1
        wait_for_update_and_click update_course_button_element
        update_course_success_element.when_visible Utils.medium_wait
      else
        logger.info 'Grading scheme already disabled'
      end
    end

    link(:features_tab, id: 'tab-features-link')
    checkbox(:new_gradebook_toggle, id: 'ff_toggle_new_gradebook')
    div(:new_gradebook_toggle_switch, xpath: '//div[contains(@class, "new_gradebook")]//div[@class="ic-Super-toggle__switch"]')

    # Ensures the new gradebook is enabled on a given course site
    # @param course [Course]
    def set_new_gradebook(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
      wait_for_load_and_click features_tab_element
      new_gradebook_toggle_element.when_present Utils.short_wait
      if new_gradebook_toggle_checked?
        logger.info 'New gradebook is already enabled'
      else
        logger.info 'Enabling new gradebook'
        wait_for_update_and_click new_gradebook_toggle_switch_element
        sleep Utils.click_wait
      end
    end

    button(:gradebook_settings_button, id: 'gradebook-settings-button')
    div(:grade_posting_policy_tab, xpath: '//div[text()="Grade Posting Policy"]')
    checkbox(:gradebook_include_ungraded, xpath: '//span[text()="Automatically apply grade for missing submissions"]/ancestor::label/preceding-sibling::input')
    paragraph(:gradebook_manual_posting_msg, xpath: '//p[contains(text(), "While the grades for an assignment are set to manual")]')
    text_field(:gradebook_manual_posting_input, xpath: '//input[@name="postPolicy"][@value="manual"]/following-sibling::label/span')
    button(:gradebook_settings_update_button, id: 'gradebook-settings-update-button')

    # Clicks the gradebook settings button
    def click_gradebook_settings
      logger.debug 'Clicking gradebook settings'
      wait_for_load_and_click gradebook_settings_button_element
    end

    # Returns whether or not ungraded assignments are included in grades
    # @return [Boolean]
    def grades_final?
      click_gradebook_settings
      gradebook_include_ungraded_element.when_present Utils.short_wait
      gradebook_include_ungraded_checked?
    end

    # Ensures that new assignments will have a manual grading policy
    # @param course [Course]
    def set_grade_policy_manual(course)
      logger.info "Setting manual posting policy for course ID #{course.site_id}"
      load_gradebook course
      click_gradebook_settings
      wait_for_update_and_click grade_posting_policy_tab_element
      gradebook_manual_posting_input_element.when_visible 2
      if gradebook_manual_posting_msg?
        logger.debug 'Posting policy is already manual'
        hit_escape
      else
        wait_for_update_and_click gradebook_manual_posting_input_element
        wait_for_update_and_click_js gradebook_settings_update_button_element
        wait_for_flash_msg('Gradebook Settings updated', Utils.medium_wait)
      end
    end


    # GRADEBOOK UI

    text_area(:user_search_input, class: 'search-query')
    link(:e_grades_export_link, xpath: '//a[contains(.,"E-Grades")]')
    button(:actions_button, xpath: '//button[contains(., "Actions")]')
    span(:grades_export_button, xpath: '//span[@data-menu-id="export"]')
    text_field(:individual_view_input, xpath: '//input[@value="Individual View"]')

    span(:assignment_hide_grades, xpath: '//span[text()="Hide grades"]')
    span(:assignment_grades_hidden, xpath: '//span[text()="All grades hidden"]')
    button(:assignment_hide_grades_hide_button, xpath: '//button[contains(., "Hide")]')
    span(:assignment_posting_policy, xpath: '//span[text()="Grade Posting Policy"]')
    text_field(:assignment_manual_posting_input, xpath: '//input[@name="postPolicy"][@value="manual"]/following-sibling::label/span')
    button(:assignment_posting_policy_save, xpath: '//button[contains(., "Save")]')

    div(:total_grade_column, xpath: '//div[contains(@id, "total_grade")]')
    link(:total_grade_menu_link, xpath: '//div[contains(@id, "total_grade")]//button')
    span(:total_grade_column_move_front, xpath: '//span[@data-menu-item-id="total-grade-move-to-front"]')

    elements(:gradebook_student_link, :link, xpath: '//a[contains(@class, "student-grades-link")]')
    elements(:gradebook_total, :span, xpath: '//div[contains(@class, "total_grade")]//span[@class="percentage"]')

    # Loads the Canvas Gradebook, switching to default view if necessary
    # @param course [Course]
    def load_gradebook(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/gradebook"
      e_grades_export_link_element.when_visible Utils.short_wait
    rescue
      if title.include? 'Individual View'
        logger.error 'Individual view is present, switching to gradebook view.'
        wait_for_update_and_click individual_view_input_element
        arrow_down
        hit_enter
        e_grades_export_link_element.when_visible Utils.medium_wait
      else
        logger.error 'E-Grades export button has not appeared, hard-refreshing the page'
        browser.execute_script('location.reload(true);')
        e_grades_export_link_element.when_visible Utils.medium_wait
      end
    end

    # Mouses over an assignment's column header to reveal the settings button
    # @param assignment [Assignment]
    def mouseover_assignment_header(assignment)
      xpath = "//div[contains(@id, 'slickgrid') and contains(@id, 'assignment_#{assignment.id}')]"
      wait_until(Utils.medium_wait) { browser.find_element(xpath: xpath) }
      mouseover(browser, browser.find_element(xpath: xpath))
    end

    # Returns the settings button for a given assignment
    # @param assignment [Assignment]
    # @return [PageObject::Elements::Button]
    def assignment_settings_button(assignment)
      button_element(xpath: "//a[contains(@href, '/assignments/#{assignment.id}')]/ancestor::div[contains(@class, 'Gradebook__ColumnHeaderContent')]//button")
    end

    # Sets a manual grading policy on a given assignment
    # @param assignment [Assignment]
    def set_assign_grade_policy_manual(assignment)
      logger.info "Setting grade posting policy to manual on assignment #{assignment.id}"
      mouseover_assignment_header assignment
      wait_for_load_and_click assignment_settings_button(assignment)
      wait_for_update_and_click assignment_posting_policy_element
      if assignment_manual_posting_input_element.attribute('tabindex') == '0'
        logger.debug 'Posting policy is already manual'
        hit_escape
      else
        wait_for_update_and_click assignment_manual_posting_input_element
        wait_for_update_and_click assignment_posting_policy_save_element
        wait_for_flash_msg('Success!', Utils.short_wait)
      end
    end

    # Hides the grades for a given assignment
    # @param assignment [Assignment]
    def hide_assignment_grades(assignment)
      logger.info "Hiding posted grades on assignment #{assignment.id}"
      mouseover_assignment_header assignment
      wait_for_load_and_click assignment_settings_button(assignment)
      wait_until(Utils.medium_wait, 'Found neither the "hide" element nor the "hidden" element') do
        assignment_hide_grades? || assignment_grades_hidden?
      end
      if assignment_grades_hidden?
        logger.debug 'Grades are already hidden'
        hit_escape
      else
        wait_for_update_and_click assignment_hide_grades_element
        sleep Utils.click_wait
        wait_for_update_and_click assignment_hide_grades_hide_button_element
        wait_for_flash_msg('Success!', Utils.medium_wait)
      end
    end

    # Downloads the grades export CSV and returns an array of hashes of UIDs and current scores
    # @param course [Course]
    # @return [Array<Hash>]
    def export_grades(course)
      Utils.prepare_download_dir
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/gradebook"
      sleep 2
      wait_for_load_and_click actions_button_element
      wait_for_update_and_click grades_export_button_element
      file_path = "#{Utils.download_dir}/*.csv"
      wait_until(Utils.long_wait, "Timed out waiting for Canvas to export grades for site ID #{course.site_id}") { Dir[file_path].any? }
      sleep Utils.short_wait
      file = Dir[file_path].first
      table = CSV.table file
      table.delete_if { |row| row[:sis_user_id].nil? || row[:sis_login_id].nil? || row[:sis_login_id].to_s.include?('inactive') }
      scores = []
      table.each { |row| scores << {:uid => row[:sis_login_id].to_s, :score => row[:current_score].to_i} }
      scores.sort_by { |s| s[:score] }
    end

    # Clicks the E-Grades export button
    def click_e_grades_export_button
      logger.info 'Clicking E-Grades Export button'
      wait_for_load_and_click e_grades_export_link_element
    end

    # Given a user and its Gradebook total score, returns the user's UID, SIS ID, and expected grade (based on the default grading scheme)
    # @param user [User]
    # @param score [Float]
    # @return [Hash]
    def student_and_grade(user, score)
      grade = case score
                when 99.9..100
                  'A+'
                when 95..99.89
                  'A'
                when 90..94.99
                  'A-'
                when 87..89.99
                  'B+'
                when 83..86.99
                  'B'
                when 80..82.99
                  'B-'
                when 77..79.99
                  'C+'
                when 73..76.99
                  'C'
                when 70..72.99
                  'C-'
                when 67..69.99
                  'D+'
                when 63..66.99
                  'D'
                when 60..62.99
                  'D-'
                when 0..59.99
                  'F'
                else
                  logger.error "Invalid score '#{score}'"
                  nil
              end
      {uid: user.uid, canvas_id: user.canvas_id, sis_id: user.sis_id, score: score, grade: grade}
    end

    # Returns the Gradebook data for a given user. If the score cannot be found, log an error but do not fail.
    # @param driver [Selenium::WebDriver]
    # @param user [User]
    # @return [Hash]
    def student_score(driver, user)
      begin
        logger.debug "Searching for score for UID #{user.uid}"
        user_search_input_element.when_visible Utils.medium_wait
        unless gradebook_total_elements.any? &:visible?
          begin
            logger.debug 'Gradebook totals are not visible, bringing them to the front'
            scroll_to_element total_grade_column_element
            mouseover(driver, driver.find_element(xpath: '//button[contains(., "Total Options")]'))
            js_click total_grade_menu_link_element
            wait_for_update_and_click total_grade_column_move_front_element
            wait_until(Utils.short_wait) { gradebook_total_elements.any? }
            sleep 2
          rescue => e
            logger.error "#{e.message}"
            fail unless gradebook_total_elements.any?
          end
        end

        # Try to find the user row a few times since stale element reference errors may occur
        tries ||= 5
        begin
          tries -= 1
          wait_for_element_and_type(user_search_input_element, user.uid)
          wait_until(2) { gradebook_student_link_elements.first.attribute('data-student_id') == "#{user.canvas_id}" }
        rescue => e
          logger.error e.message
          sleep 1
          tries.zero? ? fail : retry
        end
        sleep Utils.click_wait
        score = gradebook_total_elements.first.text.strip.delete('%').to_f
        # If the score in the UI is zero, the score might not have loaded yet. Retry.
        score = if score.zero?
                  logger.debug 'Double-checking a zero score'
                  wait_for_element_and_type(user_search_input_element, user.uid)
                  sleep 1
                  gradebook_total_elements.first.text.strip.delete('%').to_f
                else
                  score
                end
        student_and_grade(user, score)
      rescue => e
        Utils.log_error e
      end
    end

  end
end
