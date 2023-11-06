require_relative '../../util/spec_helper'

module Page

  class CanvasAssignmentsPage < CanvasPage

    include PageObject
    include Logging
    include Page

    # Loads the assignments page for a given course site
    # @param course [Course]
    def load_page(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/assignments"
    end

    # ASSIGNMENT CREATION

    link(:new_assignment_link, text: 'Assignment')
    link(:edit_assignment_link, class: 'edit_assignment_link')
    select_list(:assignment_type, id: 'assignment_submission_type')
    text_area(:assignment_name, id: 'assignment_name')
    text_area(:assignment_due_date, class: 'DueDateInput')
    checkbox(:online_url_cbx, id: 'assignment_online_url')
    checkbox(:online_upload_cbx, id: 'assignment_online_upload')
    checkbox(:online_text_entry_cbx, id: 'assignment_text_entry')
    checkbox(:online_media_cbx, id: 'assignment_media_recording')
    button(:save_assignment_button, xpath: '//button[contains(.,"Save")]')
    h1(:assignment_title_heading, class: 'title')
    button(:religious_holiday_button, xpath: '//button[contains(., "Religious Holidays Policy")]')
    link(:religious_holiday_link, xpath: '//a[contains(., "Religious Holiday and Religious Creed Policy")]')

    def load_new_assignment_page(course_site)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course_site.site_id}/assignments/new"
      assignment_name_element.when_visible Utils.medium_wait
    end

    # Begins creating a new assignment, entering title and scrolling to the submission types
    # @param course_site [Course]
    # @param assignment [Assignment]
    def enter_new_assignment_title(course_site, assignment)
      load_new_assignment_page course_site
      assignment_name_element.send_keys assignment.title
      wait_for_element_and_type_js(assignment_due_date_element, assignment.due_date.strftime("%b %-d %Y")) unless assignment.due_date.nil?
      scroll_to_element assignment_type_element
      online_url_cbx_element.when_visible Utils.short_wait
    end

    # Saves and publishes an assignment and returns its URL
    # @param assignment [Assignment]
    # @return [String]
    def save_and_publish_assignment(assignment)
      click_save_and_publish
      published_button_element.when_visible Utils.medium_wait
      logger.info "Submission assignment URL is #{current_url}"
      assignment.url = current_url
      assignment.id = assignment.url.split('/').last
      assignment.url
    end

    def create_assignment(course, assignment)
      logger.info "Creating submission assignment named '#{assignment.title}'"
      enter_new_assignment_title(course, assignment)
      check_online_url_cbx
      check_online_upload_cbx
      save_and_publish_assignment assignment
    end

    # Creates a non-sync-able assignment on a course site
    # @param course [Course]
    # @param assignment [Assignment]
    def create_unsyncable_assignment(course, assignment)
      logger.info "Creating unsyncable assignment named '#{assignment.title}'"
      enter_new_assignment_title(course, assignment)
      uncheck_online_url_cbx
      uncheck_online_upload_cbx
      check_online_text_entry_cbx
      check_online_media_cbx
      save_and_publish_assignment assignment
    end

    def edit_assignment_title(assignment)
      navigate_to assignment.url
      wait_for_load_and_click edit_assignment_link_element
      wait_for_element_and_type(assignment_name_element, (assignment.title = "#{assignment.title} - Edited"))
      wait_for_update_and_click save_assignment_button_element
      wait_until(Utils.short_wait) { assignment_title_heading_element.exists? && assignment_title_heading.include?(assignment.title) }
    end

    def expand_religious_holidays
      logger.info 'Expanding religious holiday policy section'
      wait_for_update_and_click religious_holiday_button_element
    end

    # ASSIGNMENT SUBMISSION

    button(:submit_assignment_button, xpath: '//button[text()="Start Assignment"]')
    button(:resubmit_assignment_button, xpath: '//button[text()="Re-submit Assignment"]')
    link(:assignment_file_upload_tab, class: 'submit_online_upload_option')
    button(:upload_file_button, xpath: '//button[contains(., "Upload File")]')
    text_field(:file_upload_input, name: 'attachments[0][uploaded_data]')
    button(:file_upload_submit_button, id: 'submit_file_button')
    link(:assignment_site_url_tab, class: 'submit_online_url_option')
    text_area(:url_upload_input, id: 'submission_url')
    button(:url_upload_submit_button, xpath: '(//button[@type="submit"])[2]')
    div(:assignment_submission_conf, xpath: '//div[contains(.,"Submitted!")]')

    def upload_assignment(submission)
      if submission.file_name
        wait_for_update_and_click upload_file_button_element
        file_upload_input_element.when_visible Utils.short_wait
        self.file_upload_input_element.send_keys SquiggyUtils.asset_file_path(submission.file_name)
        wait_for_update_and_click file_upload_submit_button_element
      else
        wait_for_update_and_click assignment_site_url_tab_element
        url_upload_input_element.when_visible Utils.short_wait
        self.url_upload_input = submission.url
        wait_for_update_and_click url_upload_submit_button_element
      end
    end

    def submit_assignment(assignment, user, submission)
      logger.info "Submitting #{submission.title} for #{user.full_name}"
      navigate_to assignment.url
      wait_for_load_and_click submit_assignment_button_element
      upload_assignment submission
      assignment_submission_conf_element.when_visible Utils.long_wait
    end
  end
end
