require_relative '../../util/spec_helper'

module Page

  class CanvasActivitiesPage < CanvasPage

    include PageObject
    include Logging
    include Page

    # ANNOUNCEMENTS

    link(:html_editor_link, xpath: '//a[contains(.,"HTML Editor")]')
    text_area(:announcement_msg, name: 'message')
    button(:save_announcement_button, xpath: '//h1[contains(text(),"New Discussion")]/following-sibling::div/button[contains(text(),"Save")]')
    h1(:announcement_title_heading, class: 'discussion-title')

    # Creates an announcement on a course site
    # @param course [Course]
    # @param announcement [Announcement]
    def create_announcement(course, announcement)
      logger.info "Creating announcement: #{announcement.title}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/discussion_topics/new?is_announcement=true"
      discussion_title_element.when_present Utils.short_wait
      discussion_title_element.send_keys announcement.title
      html_editor_link if html_editor_link_element.visible?
      wait_for_element_and_type_js(announcement_msg_element, announcement.body)
      wait_for_update_and_click_js save_announcement_button_element
      announcement_title_heading_element.when_visible Utils.medium_wait
      logger.info "Announcement URL is #{current_url}"
      announcement.url = current_url.gsub!('discussion_topics', 'announcements')
    end

    # DISCUSSIONS

    link(:new_discussion_link, id: 'new-discussion-btn')
    text_area(:discussion_title, id: 'discussion-title')
    checkbox(:threaded_discussion_cbx, id: 'threaded')
    checkbox(:graded_discussion_cbx, id: 'use_for_grading')
    elements(:discussion_reply, :list_item, xpath: '//ul[@class="discussion-entries"]/li')
    link(:primary_reply_link, xpath: '//article[@id="discussion_topic"]//a[@data-event="addReply"]')
    link(:primary_html_editor_link, xpath: '//article[@id="discussion_topic"]//a[contains(.,"HTML Editor")]')
    text_area(:primary_reply_input, xpath: '//article[@id="discussion_topic"]//textarea[@class="reply-textarea"]')
    button(:primary_post_reply_button, xpath: '//article[@id="discussion_topic"]//button[contains(.,"Post Reply")]')
    elements(:secondary_reply_link, :link, xpath: '//li[contains(@class,"entry")]//span[text()="Reply"]/..')
    elements(:secondary_html_editor_link, :link, xpath: '//li[contains(@class,"entry")]//a[contains(.,"HTML Editor")]')
    elements(:secondary_reply_input, :text_area, xpath: '//li[contains(@class,"entry")]//textarea[@class="reply-textarea"]')
    elements(:secondary_post_reply_button, :button, xpath: '//li[contains(@class,"entry")]//button[contains(.,"Post Reply")]')

    # Clicks the 'save and publish' button using JavaScript rather than WebDriver
    def click_save_and_publish
      scroll_to_bottom
      wait_for_update_and_click_js save_and_publish_button_element
    end

    # Creates a discussion on a course site
    # @param driver [Selenium::WebDriver]
    # @param course [Course]
    # @param discussion [Discussion]
    def create_discussion(driver, course, discussion)
      logger.info "Creating discussion topic named '#{discussion.title}'"
      load_course_site(driver, course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/discussion_topics"
      wait_for_load_and_click new_discussion_link_element
      discussion_title_element.when_present Utils.short_wait
      discussion_title_element.send_keys discussion.title
      check_threaded_discussion_cbx
      click_save_and_publish
      published_button_element.when_visible Utils.medium_wait
      logger.info "Discussion URL is #{current_url}"
      discussion.url = current_url
    end

    # Adds a reply to a discussion.  If an index is given, then adds a reply to an existing reply at that index.  Otherwise,
    # adds a reply to the topic itself.
    # @param discussion [Discussion]
    # @param index [Integer]
    # @param reply_body [String]
    def add_reply(discussion, index, reply_body)
      navigate_to discussion.url
      if index.nil?
        logger.info "Creating new discussion entry with body '#{reply_body}'"
        wait_for_load_and_click primary_reply_link_element
        primary_html_editor_link if primary_html_editor_link_element.visible?
        wait_for_element_and_type_js(primary_reply_input_element, reply_body)
        replies = discussion_reply_elements.length
        primary_post_reply_button
      else
        logger.info "Replying to a discussion entry at index #{index} with body '#{reply_body}'"
        wait_until { secondary_reply_link_elements.any? }
        wait_for_load_and_click_js secondary_reply_link_elements[index]
        wait_for_update_and_click_js(secondary_html_editor_link_elements[index]) if secondary_html_editor_link_elements[index].visible?
        wait_until(Utils.short_wait) { secondary_reply_input_elements.any? }
        wait_for_element_and_type_js(secondary_reply_input_elements[index], reply_body)
        replies = discussion_reply_elements.length
        hide_canvas_footer
        wait_for_update_and_click_js secondary_post_reply_button_elements[index]
      end
      wait_until(Utils.short_wait) { discussion_reply_elements.length == replies + 1 }
    end

    # ASSIGNMENTS

    link(:new_assignment_link, text: 'Assignment')
    select_list(:assignment_type, id: 'assignment_submission_type')
    text_area(:assignment_name, id: 'assignment_name')
    text_area(:assignment_due_date, class: 'DueDateInput')
    checkbox(:online_url_cbx, id: 'assignment_online_url')
    checkbox(:online_upload_cbx, id: 'assignment_online_upload')
    checkbox(:text_entry_cbx, id: 'assignment_text_entry')

    h1(:assignment_title_heading, class: 'title')
    link(:submit_assignment_link, text: 'Submit Assignment')
    link(:resubmit_assignment_link, text: 'Re-submit Assignment')
    link(:assignment_file_upload_tab, class: 'submit_online_upload_option')
    text_area(:file_upload_input, name: 'attachments[0][uploaded_data]')
    button(:file_upload_submit_button, id: 'submit_file_button')
    link(:assignment_site_url_tab, class: 'submit_online_url_option')
    text_area(:url_upload_input, id: 'submission_url')
    button(:url_upload_submit_button, xpath: '(//button[@type="submit"])[2]')
    div(:assignment_submission_conf, xpath: '//div[contains(.,"Turned In!")]')

    # Creates an assignment on a course site
    # @param course [Course]
    # @param assignment [Assignment]
    def create_assignment(course, assignment)
      logger.info "Creating submission assignment named '#{assignment.title}'"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/assignments/new"
      assignment_name_element.when_visible Utils.medium_wait
      assignment_name_element.send_keys assignment.title
      wait_for_element_and_type_js(assignment_due_date_element, assignment.due_date.strftime("%b %-d %Y")) unless assignment.due_date.nil?
      assignment_type_element.when_visible Utils.medium_wait
      scroll_to_bottom
      wait_for_element_and_select_js(assignment_type_element, 'Online')
      online_url_cbx_element.when_visible Utils.short_wait
      check_online_url_cbx
      check_online_upload_cbx
      click_save_and_publish
      published_button_element.when_visible Utils.medium_wait
      logger.info "Submission assignment URL is #{current_url}"
      assignment.url = current_url
    end

    # Upload's a user's asset as an assignment submission
    # @param assignment [Assignment]
    # @param user [User]
    # @submission [Asset]
    def submit_assignment(assignment, user, submission)
      logger.info "Submitting #{submission.title} for #{user.full_name}"
      navigate_to assignment.url
      wait_for_load_and_click_js submit_assignment_link_element
      case submission.type
        when 'File'
          file_upload_input_element.when_visible Utils.short_wait
          self.file_upload_input_element.send_keys Utils.test_data_file_path(submission.file_name)
          wait_for_update_and_click_js file_upload_submit_button_element
        when 'Link'
          wait_for_update_and_click_js assignment_site_url_tab_element
          url_upload_input_element.when_visible Utils.short_wait
          self.url_upload_input = submission.url
          wait_for_update_and_click_js url_upload_submit_button_element
        else
          logger.error 'Unsupported submission type in test data'
      end
      assignment_submission_conf_element.when_visible Utils.long_wait
    end

    # FILES

    div(:file_search_no_results, xpath: '//div[contains(.,"This folder is empty")]')

    # Loads the Files page for a given course
    # @param course [Course]
    def load_files(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/files"
    end

    # Searches for a file in a course site
    # @param course [Course]
    # @param file_name [String]
    def search_for_file(course, file_name)
      logger.info "Searching the course Files system for a file named '#{file_name}'"
      load_files course
      wait_for_element_and_type(text_area_element(xpath: '//input[@placeholder="Search for files"]'), file_name)
      wait_for_update_and_click div_element(xpath: '//button[@type="submit"]')
    end

    # Verifies that the asset file directory on a course site is set to 'hidden' but visible to the right user roles
    # @param course [Course]
    # @param user [User]
    # @return [boolean]
    def suitec_files_hidden?(course, user)
      load_files course
      div_element(class: 'ef-folder-list').when_visible Utils.medium_wait
      ['Teacher', 'Lead TA', 'TA', 'Designer', 'Reader'].include?(user.role) ?
          verify_block { button_element(xpath: '//a[contains(.,"_suitec")]/../following-sibling::div[5]/button[@title="Hidden. Available with a link"]').when_visible Utils.short_wait } :
          verify_block { file_search_no_results_element.when_visible Utils.short_wait }
    end

    # GRADES

    checkbox(:set_grading_scheme_cbx, id: 'course_grading_standard_enabled')
    link(:assignment_heading_link, xpath: '//a[@class="gradebook-header-drop assignment_header_drop"]')
    link(:toggle_muting_link, xpath: '//a[@data-action="toggleMuting"]')
    button(:mute_assignment_button, xpath: '//button[contains(.,"Mute Assignment")]')
    link(:e_grades_export_link, xpath: '//a[contains(.,"E-Grades")]')

    # Loads the Canvas Gradebook
    # @param course [Course]
    def load_gradebook(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/gradebook"
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

    # Clicks the E-Grades export button
    def click_e_grades_export_button
      logger.info 'Clicking E-Grades Export button'
      wait_for_load_and_click e_grades_export_link_element
    end

  end
end
