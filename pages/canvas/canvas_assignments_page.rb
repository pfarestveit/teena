require_relative '../../util/spec_helper'

module Page

  class CanvasAssignmentsPage < CanvasPage

    include PageObject
    include Logging
    include Page

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
      assignment_name_element.when_present Utils.medium_wait
    end

    def enter_new_assignment_title(course_site, assignment)
      load_new_assignment_page course_site
      assignment_name_element.send_keys assignment.title
      wait_for_element_and_type_js(assignment_due_date_element, assignment.due_date.strftime("%b %-d %Y")) unless assignment.due_date.nil?
      scroll_to_element assignment_type_element
      online_url_cbx_element.when_visible Utils.short_wait
    end

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

    def expand_religious_holidays
      logger.info 'Expanding religious holiday policy section'
      wait_for_update_and_click religious_holiday_button_element
    end
  end
end
