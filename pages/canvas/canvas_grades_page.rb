require_relative '../../util/spec_helper'

module Page

  class CanvasGradesPage < CanvasPage

    include PageObject
    include Logging
    include Page

    # COURSE LEVEL GRADEBOOK-RELATED SETTINGS

    link(:view_grading_scheme_link, text: 'view grading scheme')
    select_list(:grading_scheme_select, xpath: '//div[@id="grading_scheme_selector"]//select')
    link(:select_another_scheme_link, xpath: '//a[@title="Find an Existing Grading Scheme"]')
    button(:done_button, xpath: '//button[text()="Done"]')

    # Ensures that no grading scheme is set on a course site
    # @param course [Course]
    def disable_grading_scheme(course)
      logger.info "Making sure grading scheme is disabled for course ID #{course.site_id}"
      load_course_settings course
      scroll_to_bottom
      set_grading_scheme_cbx_checked? ?  toggle_grading_scheme : logger.info('Grading scheme already disabled')
    end

    # Ensures that a grading scheme is set on a course site
    # @param course [Course]
    def enable_grading_scheme(course)
      logger.info "Making sure grading scheme is enabled for course ID #{course.site_id}"
      load_course_settings course
      scroll_to_bottom
      !set_grading_scheme_cbx_checked? ?  toggle_grading_scheme : logger.info('Grading scheme already enabled')
    end

    # Sets a given grading scheme on a course site
    # @param opts [Hash] - :scheme
    def set_grading_scheme(opts)
      logger.info "Setting grading scheme to #{opts[:scheme]}"
      option = case opts[:scheme]
                  when 'letter-only'
                    'Letter Grade Scale'
                  when 'letter'
                    'Letter Grades with +/-'
                  when 'pnp'
                    'Pass/No Pass'
                  when 'sus'
                    'Satisfactory/Unsatisfactory'
                  else
                    logger.error "Unrecognized grading scheme '#{opts[:scheme]}'"
                    fail
                  end
      wait_for_element_and_select(grading_scheme_select_element, option)
      update_course_settings
    end

    # Clicks the update button and waits for confirmation
    def update_course_settings
      wait_for_update_and_click_js update_course_button_element
      sleep 2
      update_course_success_element.when_visible Utils.medium_wait
    end

    # Clicks the grading scheme checkbox and awaits confirmation of the update. Sometimes the confirmation does not appear, so
    # retries once.
    def toggle_grading_scheme
      wait_for_update_and_click set_grading_scheme_cbx_element
      update_course_settings
    rescue => e
      logger.error e.message
      update_course_settings
    end

    button(:gradebook_settings_button, xpath: '//button[@data-test-id="gradebook-settings-button"]')
    div(:grade_posting_policy_tab, id: 'tab-tab-panel-post')
    checkbox(:gradebook_include_ungraded, xpath: '//span[text()="Automatically apply grade for missing submissions"]/ancestor::label/preceding-sibling::input')
    paragraph(:gradebook_manual_posting_msg, xpath: '//p[contains(text(), "While the grades for an assignment are set to manual")]')
    text_field(:gradebook_manual_posting_input, xpath: '//input[@name="postPolicy"][@value="manual"]/following-sibling::label/span')
    button(:gradebook_settings_update_button, id: 'gradebook-settings-update-button')

    # Clicks the gradebook settings button, which can be a fickle button
    def click_gradebook_settings
      tries = 3
      begin
        logger.debug 'Clicking gradebook settings'
        wait_for_load_and_click gradebook_settings_button_element
        grade_posting_policy_tab_element.when_visible Utils.short_wait
      rescue
        retry unless (tries -= 1).zero?
      end
    end

    # Returns whether or not ungraded assignments are included in grades
    # @return [Boolean]
    def grades_final?
      sleep Utils.click_wait
      click_gradebook_settings
      gradebook_include_ungraded_element.when_present Utils.medium_wait
      gradebook_include_ungraded_checked?
    end

    # Ensures that new assignments will have a manual grading policy
    # @param course [Course]
    def set_grade_policy_manual(course)
      logger.info "Setting manual posting policy for course ID #{course.site_id}"
      load_gradebook course
      click_gradebook_settings
      sleep 1
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

    text_area(:user_search_input, xpath: '//input[@placeholder="Search Students"]')
    link(:e_grades_export_link, xpath: '//a[contains(.,"E-Grades")]')
    button(:actions_button, xpath: '//button[contains(., "Actions")]')
    span(:grades_export_button, xpath: '//span[@data-menu-id="export"]')
    text_field(:individual_view_input, xpath: '//input[@value="Individual View"]')

    span(:assignment_hide_grades, xpath: '//span[text()="Hide grades"]')
    span(:assignment_grades_hidden, xpath: '//span[text()="All grades hidden"]')
    button(:assignment_hide_grades_hide_button, xpath: '//button[contains(., "Hide")]')
    span(:assignment_posting_policy, xpath: '//span[text()="Grade Posting Policy"]')
    text_field(:assignment_manual_posting_input, xpath: '//input[@name="postPolicy"][@value="manual"]')
    span(:assignment_manual_posting_radio, xpath: '//input[@name="postPolicy"][@value="manual"]/following-sibling::label/span')
    button(:assignment_posting_policy_save, xpath: '//button[contains(., "Save")]')

    div(:total_grade_column, xpath: '//div[contains(@id, "total_grade")]')
    link(:total_grade_menu_link, xpath: '//div[contains(@id, "total_grade")]//button')
    span(:total_grade_column_move_front, xpath: '//span[@data-menu-item-id="total-grade-move-to-front"]')

    elements(:gradebook_student_link, :link, xpath: '//a[contains(@class, "student-grades-link")]')
    elements(:gradebook_total, :span, xpath: '//div[contains(@class, "total_grade")]//span[@class="percentage"]')
    elements(:gradebook_grade, :span, xpath: '//div[contains(@class, "total_grade")]//span[@class="letter-grade-points"]')

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
      wait_until(Utils.medium_wait) { div_element(xpath: xpath).exists? }
      mouseover(div_element(xpath: xpath))
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
        wait_for_update_and_click assignment_manual_posting_radio_element
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

    def search_for_gradebook_student(user)
      # Try to find the user row a few times since stale element reference errors may occur
      tries ||= 5
      begin
        tries -= 1
        wait_for_element(user_search_input_element, Utils.medium_wait)
        remove_button = button_element(xpath: '//button[contains(@title, "Remove ")]')
        remove_button.click if remove_button.exists?
        wait_for_textbox_and_type(user_search_input_element, user.full_name)
        hit_enter
        wait_until(2) { gradebook_student_link_elements.first.attribute('data-student_id') == "#{user.canvas_id}" }
      rescue => e
        logger.error e.message
        sleep 1
        hit_escape # in case a modal has been left open, obscuring the search input
        tries.zero? ? fail : retry
      end
    end

    # Returns the Gradebook data for a given user. If the score cannot be found, log an error but do not fail.
    # @param user [User]
    # @return [Hash]
    def student_score(user)
      begin
        logger.debug "Searching for score for UID #{user.uid}"
        user_search_input_element.when_visible Utils.medium_wait
        wait_until(Utils.short_wait) { gradebook_total_elements.any? } rescue logger.error('Timed out waiting for gradebook totals')
        unless gradebook_total_elements.any?
          begin
            logger.debug 'Gradebook totals are not visible, bringing them to the front'
            scroll_to_element total_grade_column_element
            mouseover(button_element(xpath: '//button[contains(., "Total Options")]'))
            js_click total_grade_menu_link_element
            wait_for_update_and_click total_grade_column_move_front_element
            wait_until(Utils.short_wait) { gradebook_total_elements.any? }
            sleep 2
          rescue => e
            logger.error "#{e.message}"
            fail unless gradebook_total_elements.any?
          end
        end

        search_for_gradebook_student user
        sleep Utils.click_wait
        wait_until(Utils.short_wait) { gradebook_grade_elements.any? }
        grade = gradebook_grade_elements.first.text
        {
            student: user,
            grade: grade
        }
      rescue => e
        Utils.log_error e
      end
    end

    # FINAL GRADE OVERRIDES

    link(:features_tab, id: 'tab-features-link')
    checkbox(:grade_override_toggle, id: 'ff_toggle_final_grades_override')
    div(:grade_override_toggle_switch, xpath: '//div[contains(@class, "final_grades_override")]//div[@class="ic-Super-toggle__switch"]')

    div(:adv_gradebook_settings_tab, id: 'tab-tab-panel-advanced')
    checkbox(:allow_grade_override_cbx, xpath: '//label[contains(., "Allow final grade override")]/preceding-sibling::input')
    button(:update_gradebook_settings, id: 'gradebook-settings-update-button')

    div(:grade_override_cell, xpath: '//div[contains(@class, "total-grade-override") and contains(@class, "slick-cell")]/div')
    text_field(:grade_override_input, xpath: '//div[contains(@class, "total-grade-override")]//input')
    elements(:grid_row_cell, :div, xpath: '//div[@id="gradebook_grid"]//div[contains(@class, "first-row")]/div')

    # Clicks the settings icon and switches to advanced settings
    def open_gradebook_adv_settings
      click_gradebook_settings
      sleep 1
      adv_gradebook_settings_tab_element.click
      allow_grade_override_cbx_element.when_visible 1
    end

    # Clicks the allow-override checkbox and saves
    def toggle_allow_grade_override
      js_click allow_grade_override_cbx_element
      wait_for_update_and_click_js update_gradebook_settings_element
      flash_msg_element.when_visible Utils.short_wait
      wait_until(1) { flash_msg_element.text.include? 'Gradebook Settings updated' }
    end

    # Ensures that allow-override is selected on the gradebook
    def allow_grade_override
      open_gradebook_adv_settings
      if allow_grade_override_cbx_checked?
        logger.info 'Final grade override is already allowed'
        hit_escape
        allow_grade_override_cbx_element.when_not_present 1
      else
        logger.info 'Allowing final grade override'
        toggle_allow_grade_override
      end
    end

    # Ensures that allow-override is not selected on the gradebook
    def disallow_grade_override
      open_gradebook_adv_settings
      if allow_grade_override_cbx_checked?
        logger.info 'Disallowing final grade override'
        toggle_allow_grade_override
      else
        logger.info 'Final grade override is already disallowed'
        hit_escape
        allow_grade_override_cbx_element.when_not_present 1
      end
    end

    # Enters a given override grade for a given student
    def enter_override_grade(course, student, grade)
      logger.info "Entering override grade '#{grade}' for UID #{student.uid}"
      load_gradebook course
      allow_grade_override
      search_for_gradebook_student student
      15.times do
        visible_els = grid_row_cell_elements
        scroll_to_element visible_els.last
      end
      sleep 1
      wait_for_update_and_click grade_override_cell_element
      wait_for_element_and_type(grade_override_input_element, grade)
      sleep Utils.click_wait
      hit_enter
      sleep Utils.click_wait
    end

  end
end
