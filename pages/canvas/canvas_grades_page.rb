require_relative '../../util/spec_helper'

module Page

  class CanvasGradesPage < CanvasPage

    include PageObject
    include Logging
    include Page

    # COURSE LEVEL GRADEBOOK-RELATED SETTINGS

    link(:view_grading_scheme_link, text: 'view grading scheme')
    select_list(:grading_scheme_select, id: 'grading-schemes-selector-dropdown')
    link(:select_another_scheme_link, xpath: '//a[@title="Find an Existing Grading Scheme"]')
    button(:done_button, xpath: '//button[text()="Done"]')

    def disable_grading_scheme(course_site)
      logger.info "Making sure grading scheme is disabled for course ID #{course_site.site_id}"
      load_course_settings course_site
      scroll_to_bottom
      if grading_scheme_select?
        wait_for_update_and_click set_grading_scheme_cbx_element
        grading_scheme_select_element.when_not_present(2)
        update_course_settings
      else
        logger.info('Grading scheme already disabled')
      end
    end

    def enable_grading_scheme(course_site)
      logger.info "Making sure grading scheme is enabled for course ID #{course_site.site_id}"
      load_course_settings course_site
      scroll_to_bottom
      if grading_scheme_select?
        logger.info('Grading scheme already enabled')
      else
        wait_for_update_and_click set_grading_scheme_cbx_element
        grading_scheme_select_element.when_present(5)
        update_course_settings
      end
    end

    def set_grading_scheme(opts)
      desired_scheme = case opts[:scheme]
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
      visible_options = ['Letter Grade Scale', 'Letter Grades with +/-', 'Pass/No Pass', 'Satisfactory/Unsatisfactory']
      desired_option = visible_options.find { |o| o == desired_scheme }
      grading_scheme_select_element.when_visible Utils.short_wait
      current_scheme = grading_scheme_select_element.attribute('value').strip
      logger.info "The currently set grading scheme is #{current_scheme}, and setting it to #{desired_option}"
      unless current_scheme == desired_option
        current_idx = visible_options.index current_scheme
        new_idx = visible_options.index desired_option
        wait_for_update_and_click grading_scheme_select_element
        if current_idx
          if new_idx > current_idx
            (new_idx - current_idx).times { arrow_down }
          else
            (current_idx - new_idx).times { arrow_up }
          end
        else
          (new_idx + 1).times { arrow_down }
        end
        hit_enter
      end
      update_course_settings
      grading_scheme_select_element.when_visible Utils.short_wait
      logger.info "The newly set grading scheme is #{grading_scheme_select_element.attribute('value')}"
    end

    def update_course_settings
      hide_canvas_footer_and_popup
      scroll_to_bottom
      wait_for_update_and_click update_course_button_element
      sleep 2
      update_course_success_element.when_visible Utils.medium_wait
    end

    button(:gradebook_settings_button, xpath: '//button[@data-testid="gradebook-settings-button"]')
    div(:grade_posting_policy_tab, id: 'tab-tab-panel-post')
    checkbox(:gradebook_include_ungraded, xpath: '//span[text()="Automatically apply grade for missing submissions"]/ancestor::label/preceding-sibling::input')
    paragraph(:gradebook_manual_posting_msg, xpath: '//p[contains(text(), "While the grades for an assignment are set to manual")]')
    text_field(:gradebook_manual_posting_input, xpath: '//input[@name="postPolicy"][@value="manual"]/following-sibling::label/span')
    button(:gradebook_settings_update_button, id: 'gradebook-settings-update-button')

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

    def grades_final?
      sleep Utils.click_wait
      click_gradebook_settings
      gradebook_include_ungraded_element.when_present Utils.medium_wait
      gradebook_include_ungraded_checked?
    end

    def set_grade_policy_manual(course_site)
      logger.info "Setting manual posting policy for course ID #{course_site.site_id}"
      load_gradebook course_site
      click_gradebook_settings
      sleep 1
      wait_for_update_and_click grade_posting_policy_tab_element
      gradebook_manual_posting_input_element.when_visible 2
      if gradebook_manual_posting_msg?
        logger.debug 'Posting policy is already manual'
        hit_escape
      else
        wait_for_update_and_click gradebook_manual_posting_input_element
        wait_for_update_and_click gradebook_settings_update_button_element
        wait_for_flash_msg('Gradebook Settings updated', Utils.medium_wait)
      end
    end

    # GRADEBOOK UI

    text_area(:student_search_input, xpath: '//input[@placeholder="Search Students"]')
    link(:e_grades_export_link, xpath: '(//a[contains(text(), "E-Grades")])[last()]')
    button(:actions_button, xpath: '//button[contains(., "Actions")]')
    text_field(:individual_view_input, xpath: '//input[@value="Individual View"]')

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
    elements(:gradebook_un_posted_msg, :div, xpath: '//div[contains(@class, "total_grade")]//div[contains(text(), "not yet posted")]')

    def load_gradebook(course_site)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course_site.site_id}/gradebook"
      e_grades_export_link_element.when_present Utils.short_wait
    rescue
      if title.include? 'Individual View'
        logger.error 'Individual view is present, switching to gradebook view.'
        wait_for_update_and_click individual_view_input_element
        arrow_down
        hit_enter
        e_grades_export_link_element.when_present Utils.medium_wait
      else
        logger.error 'E-Grades export button has not appeared, hard-refreshing the page'
        browser.execute_script('location.reload(true);')
        e_grades_export_link_element.when_present Utils.medium_wait
      end
    end

    def mouseover_assignment_header(assignment)
      xpath = "//div[contains(@id, 'slickgrid') and contains(@id, 'assignment_#{assignment.id}')]"
      wait_until(Utils.medium_wait) { div_element(xpath: xpath).exists? }
      mouseover(div_element(xpath: xpath))
    end

    def assignment_settings_button(assignment)
      button_element(xpath: "//a[contains(@href, '/assignments/#{assignment.id}')]/ancestor::div[contains(@class, 'Gradebook__ColumnHeaderContent')]//button")
    end

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

    def click_e_grades_export_button
      logger.info 'Clicking E-Grades Export button'
      wait_for_load_and_click e_grades_export_link_element
    end

    def search_for_gradebook_student(user)
      # Try to find the user row a few times since stale element reference errors may occur
      tries ||= 2
      begin
        tries -= 1
        wait_for_element(student_search_input_element, Utils.medium_wait)
        remove_button = button_element(xpath: '//button[contains(@title, "Remove ")]')
        remove_button.click if remove_button.exists?
        wait_for_textbox_and_type(student_search_input_element, user.full_name)
        hit_enter
        wait_until(2) { gradebook_student_link_elements.first.attribute('data-student_id') == "#{user.canvas_id}" }
      rescue => e
        logger.error e.message
        sleep 1
        hit_escape # in case a modal has been left open, obscuring the search input
        tries.zero? ? fail : retry
      end
    end

    def student_score(user)
      begin
        logger.debug "Searching for score for UID #{user.uid}"
        student_search_input_element.when_visible Utils.medium_wait
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
            grade: grade&.gsub('−', '-'),
            un_posted: gradebook_un_posted_msg_elements.any?
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

    def open_gradebook_adv_settings
      click_gradebook_settings
      sleep 1
      adv_gradebook_settings_tab_element.click
      allow_grade_override_cbx_element.when_visible 1
    end

    def toggle_allow_grade_override
      js_click allow_grade_override_cbx_element
      wait_for_update_and_click update_gradebook_settings_element
      flash_msg_element.when_visible Utils.short_wait
      wait_until(1) { flash_msg_element.text.include? 'Gradebook Settings updated' }
    end

    def allow_grade_override
      open_gradebook_adv_settings
      if allow_grade_override_cbx_checked?
        logger.info 'Final grade override is already allowed'
        sleep 1
        hit_escape
        allow_grade_override_cbx_element.when_not_present 1
      else
        logger.info 'Allowing final grade override'
        toggle_allow_grade_override
      end
    end

    def disallow_grade_override
      open_gradebook_adv_settings
      if allow_grade_override_cbx_checked?
        logger.info 'Disallowing final grade override'
        toggle_allow_grade_override
      else
        logger.info 'Final grade override is already disallowed'
        sleep 1
        hit_escape
        allow_grade_override_cbx_element.when_not_present 1
      end
    end

    def enter_override_grade(course_site, student, grade)
      logger.info "Entering override grade '#{grade}' for UID #{student.uid}"
      load_gradebook course_site
      allow_grade_override
      search_for_gradebook_student student
      15.times do
        visible_els = grid_row_cell_elements
        scroll_to_element visible_els.last
      end
      sleep 1
      wait_for_update_and_click grade_override_cell_element
      wait_for_textbox_and_type(grade_override_input_element, grade)
      sleep Utils.click_wait
      hit_enter
      sleep Utils.click_wait
    end

  end
end
