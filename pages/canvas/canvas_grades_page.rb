require_relative '../../util/spec_helper'

module Page

  class CanvasGradesPage < CanvasPage

    include PageObject
    include Logging
    include Page

    # GRADES

    link(:switch_to_default_gradebook, id: 'switch_to_default_gradebook')
    text_area(:user_search_input, class: 'search-query')
    link(:e_grades_export_link, xpath: '//a[contains(.,"E-Grades")]')
    button(:grades_export_button, id: 'download_csv')
    link(:grades_csv_link, xpath: '//a[text()="CSV File"]')

    div(:total_grade_column, xpath: '//div[contains(@id, "total_grade")]')
    link(:total_grade_menu_link, id: 'total_dropdown')
    span(:total_grade_column_menu, class: 'gradebook-header-menu')
    span(:total_grade_column_move_front, xpath: '//ul[contains(@class, "gradebook-header-menu")]//*[contains(.,"Move to front")]')

    elements(:gradebook_row, :link, xpath: '//div[@class="canvas_0 grid-canvas"]//div[@class="student-name"]')
    elements(:gradebook_uid, :div, class: 'secondary_identifier_cell')
    elements(:gradebook_total, :span, xpath: '//span[@class="letter-grade-points"]/preceding-sibling::span')

    button(:gradebook_settings_button, id: 'gradebook_settings')
    checkbox(:gradebook_include_ungraded, id: 'include-ungraded-list-item')

    checkbox(:set_grading_scheme_cbx, id: 'course_grading_standard_enabled')
    link(:assignment_heading_link, xpath: '//a[@class="gradebook-header-drop assignment_header_drop"]')
    link(:toggle_muting_link, xpath: '//a[@data-action="toggleMuting"]')
    button(:mute_assignment_button, xpath: '//button[contains(.,"Mute Assignment")]')

    # Loads the Canvas Gradebook, switching to default view if necessary
    # @param course [Course]
    def load_gradebook(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/gradebook"
      e_grades_export_link_element.when_visible Utils.medium_wait rescue switch_to_default_gradebook
    end

    # Ensures that no grading scheme is set on a course site
    # @param course [Course]
    def disable_grading_scheme(course)
      logger.info "Making sure grading scheme is disabled for course ID #{course.site_id}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings"
      set_grading_scheme_cbx_element.when_present Utils.medium_wait
      wait_for_update_and_click_js set_grading_scheme_cbx_element if set_grading_scheme_cbx_checked?
      wait_for_update_and_click_js update_course_button_element
      update_course_success_element.when_visible Utils.medium_wait
    end

    # Clicks the first assignment heading to reveal whether or not the assignment is muted
    def click_first_assignment_heading
      link_element(xpath: '//a[@class="gradebook-header-drop assignment_header_drop"]').when_present Utils.medium_wait
      link_element(xpath: '//a[@class="gradebook-header-drop assignment_header_drop"]').click
    end

    # Ensures that an assignment is muted on a course site
    # @param course [Course]
    def mute_assignment(course)
      logger.info "Muting an assignment for course ID #{course.site_id}"
      load_gradebook course
      click_first_assignment_heading
      toggle_muting_link_element.when_visible Utils.short_wait
      if toggle_muting_link_element.text == 'Mute Assignment'
        toggle_muting_link_element.click
        wait_for_update_and_click mute_assignment_button_element
        paragraph_element(xpath: '//p[contains(.,"Are you sure you want to mute this assignment?")]').when_not_visible(Utils.medium_wait) rescue Selenium::WebDriver::Error::StaleElementReferenceError
      else
        logger.debug 'An assignment is already muted'
      end
    end

    # Downloads the grades export CSV and returns an array of hashes of UIDs and current scores
    # @param course [Course]
    # @return [Array<Hash>]
    def export_grades(course)
      Utils.prepare_download_dir
      load_gradebook course
      sleep 2
      wait_for_load_and_click grades_export_button_element
      wait_for_update_and_click grades_csv_link_element
      file_path = "#{Utils.download_dir}/*.csv"
      wait_until(Utils.medium_wait) { Dir[file_path].any? }
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
              end
      {uid: user.uid, canvas_id: user.canvas_id, sis_id: user.sis_id, score: score, grade: grade}
    end

    # Clicks the gradebook settings button
    def click_gradebook_settings
      logger.debug 'Clicking gradebook settings'
      wait_for_load_and_click gradebook_settings_button_element
    end

    # Returns the Gradebook data for a given user
    # @param user [User]
    # @return [Hash]
    def student_score(user)
      user_search_input_element.when_visible Utils.medium_wait
      self.user_search_input = user.uid
      wait_until(2) { gradebook_uid_elements.first.text == "#{user.uid}" }
      unless gradebook_total_elements.any? &:visible?
        wait_for_update_and_click_js total_grade_column_element
        js_click total_grade_menu_link_element
        sleep 1
        total_grade_column_move_front_element.click if total_grade_column_move_front_element.exists?
        wait_until(Utils.medium_wait) { gradebook_total_elements.any? }
      end
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
    end

  end
end
