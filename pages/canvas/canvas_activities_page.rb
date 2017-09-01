require_relative '../../util/spec_helper'

module Page

  class CanvasActivitiesPage < CanvasPage

    include PageObject
    include Logging
    include Page

    link(:settings_link, class: 'announcement_cog')
    link(:delete_link, class: 'delete_discussion')

    # Deletes an announcement or a discussion
    # @param title [String]
    # @param url [String]
    def delete_activity(title, url)
      logger.info "Deleting '#{title}'"
      navigate_to url
      wait_for_load_and_click settings_link_element
      confirm(true) { wait_for_update_and_click delete_link_element }
      list_item_element(xpath: "//li[contains(.,'#{title} deleted successfully')]").when_present Utils.short_wait
    end

    # ANNOUNCEMENTS

    link(:html_editor_link, xpath: '//a[contains(.,"HTML Editor")]')
    text_area(:announcement_msg, name: 'message')
    button(:save_announcement_button, xpath: '//h1[contains(text(),"New Discussion")]/following-sibling::div/button[contains(text(),"Save")]')
    h1(:announcement_title_heading, class: 'discussion-title')

    # Creates an announcement on a course site
    # @param course [Course]
    # @param announcement [Announcement]
    def create_course_announcement(course, announcement)
      logger.info "Creating announcement: #{announcement.title}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/discussion_topics/new?is_announcement=true"
      enter_and_save_announcement announcement
    end

    # Creates an announcement in a group within a course site
    # @param group [Group]
    # @param announcement [Announcement]
    def create_group_announcement(group, announcement)
      logger.info "Creating group announcement: #{announcement.title}"
      navigate_to "#{Utils.canvas_base_url}/groups/#{group.site_id}/discussion_topics/new?is_announcement=true"
      enter_and_save_announcement announcement
    end

    def enter_and_save_announcement(announcement)
      discussion_title_element.when_present Utils.short_wait
      discussion_title_element.send_keys announcement.title
      html_editor_link if html_editor_link_element.visible?
      wait_for_element_and_type_js(announcement_msg_element, announcement.body)
      wait_for_update_and_click_js save_announcement_button_element
      announcement_title_heading_element.when_visible Utils.medium_wait
      logger.info "Announcement URL is #{announcement.url = current_url}"
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
    def create_course_discussion(driver, course, discussion)
      logger.info "Creating discussion topic named '#{discussion.title}'"
      load_course_site(driver, course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/discussion_topics"
      enter_and_save_discussion discussion
    end

    # Creates a discussion on a group site
    # @param group [Group]
    # @param discussion [Discussion]
    def create_group_discussion(group, discussion)
      logger.info "Creating group discussion topic named '#{discussion.title}'"
      navigate_to "#{Utils.canvas_base_url}/groups/#{group.site_id}/discussion_topics"
      enter_and_save_discussion discussion
    end

    # Enters and saves a discussion topic
    # @param discussion [Discussion]
    def enter_and_save_discussion(discussion)
      wait_for_load_and_click new_discussion_link_element
      discussion_title_element.when_present Utils.short_wait
      discussion_title_element.send_keys discussion.title
      js_click threaded_discussion_cbx_element
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
    checkbox(:online_text_entry_cbx, id: 'assignment_text_entry')
    checkbox(:online_media_cbx, id: 'assignment_media_recording')
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

    # Begins creating a new assignment, entering title and scrolling to the submission types
    # @param course [Course]
    # @param assignment [Assignment]
    def enter_new_assignment_title(course, assignment)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/assignments/new"
      assignment_name_element.when_visible Utils.medium_wait
      assignment_name_element.send_keys assignment.title
      wait_for_element_and_type_js(assignment_due_date_element, assignment.due_date.strftime("%b %-d %Y")) unless assignment.due_date.nil?
      scroll_to_element assignment_type_element
      online_url_cbx_element.when_visible Utils.short_wait
    end

    # Saves and publishes an assingment and returns its URL
    # @param assignment [Assignment]
    # @return [String]
    def save_and_publish_assignment(assignment)
      click_save_and_publish
      published_button_element.when_visible Utils.medium_wait
      logger.info "Submission assignment URL is #{current_url}"
      assignment.url = current_url
    end

    # Creates a sync-able assignment on a course site
    # @param course [Course]
    # @param assignment [Assignment]
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
      check_online_text_entry_cbx
      check_online_media_cbx
      save_and_publish_assignment assignment
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
    span(:suitec_dir, xpath: '//span[contains(.,"_suitec")]')

    # Loads the Files page for a given course
    # @param course [Course]
    def load_files(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/files"
    end

    # Loads the SuiteC files directory for a given course
    # @param course [Course]
    def load_suitec_files(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/files/_suitec"
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

    # GROUPS

    link(:groups_link, text: 'Groups')
    link(:student_groups_link, text: 'Student Groups')
    text_area(:add_group_name_input, id: 'groupName')
    link(:edit_group_link, id: 'edit_group')
    text_area(:edit_group_name_input, id: 'group_name')
    button(:save_button, xpath: '//button[contains(.,"Save")]')

    # Loads the groups page on a course site
    # @param course [Course]
    def load_course_grps(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/groups"
    end

    # Creates a new group as a student and populates its members
    # @param course [Course]
    # @param group [Group]
    def student_create_grp(course, group)
      load_course_grps course
      logger.info "Student is creating a student group called '#{group.title}' with #{group.members.length} additional members"
      wait_for_update_and_click button_element(class: 'add_group_link')
      wait_for_element_and_type(add_group_name_input_element, group.title)
      group.members.each do |member|
        scroll_to_bottom
        (checkbox = checkbox_element(xpath: "//span[text()='#{member.full_name}']/preceding-sibling::input")).when_present Utils.short_wait
        checkbox.check
      end
      wait_for_update_and_click submit_button_element
      (link = student_visit_grp_link(group)).when_present Utils.short_wait
      logger.info "Group ID is '#{group.site_id = link.attribute('href').split('/').last}'"
    end

    # Returns the 'visit' link for an existing group
    # @param group [Group]
    # @return [PageObject::Elements::Link]
    def student_visit_grp_link(group)
      link_element(xpath: "//a[contains(@aria-label,'Visit group #{group.title}')]")
    end

    # Visits a group on a course site as a student
    # @param course [Course]
    # @param group [Group]
    def student_visit_grp(course, group)
      load_course_grps course
      logger.info "Visiting group '#{group.title}'"
      wait_for_update_and_click student_visit_grp_link(group)
      wait_until(Utils.short_wait) { recent_activity_heading.include? group.title }
    end

    # Joins a group on a course site
    # @param course [Course]
    # @param group [Group]
    def student_join_grp(course, group)
      load_course_grps course
      logger.info "Joining group '#{group.title}'"
      wait_for_update_and_click link_element(xpath: "//a[contains(@aria-label,'Join group #{group.title}')]")
      list_item_element(xpath: '//li[contains(.,"Joined Group")]').when_present Utils.short_wait
    end

    # Leaves a group on a course site
    # @param course [Course]
    # @param group [Group]
    def student_leave_grp(course, group)
      load_course_grps course
      logger.info "Leaving group '#{group.title}'"
      wait_for_update_and_click link_element(xpath: "//a[contains(@aria-label,'Leave group #{group.title}')]")
      list_item_element(xpath: '//li[contains(.,"Left Group")]').when_present Utils.short_wait
    end

    # Edits the name of a group on a course site
    # @param course [Course]
    # @param group [Group]
    # @param new_name [String]
    def student_edit_grp_name(course, group, new_name)
      student_visit_grp(course, group)
      logger.debug "Changing group title to '#{group.title = new_name}'"
      wait_for_update_and_click edit_group_link_element
      wait_for_element_and_type(edit_group_name_input_element, group.title)
      wait_for_update_and_click save_button_element
      wait_until(Utils.short_wait) { recent_activity_heading.include? group.title }
    end

    # As an instructor, creates a new group set and a group
    # @param course [Course]
    # @param group [Group]
    def instructor_create_grp(course, group)
      load_course_grps course

      # Create new group set
      logger.info "Creating new group set called '#{group.group_set}'"
      (button = button_element(xpath: '//button[@id="add-group-set"]')).when_present Utils.short_wait
      js_click button
      wait_for_element_and_type(text_area_element(id: 'new_category_name'), group.group_set)
      checkbox_element(id: 'enable_self_signup').check
      button_element(id: 'newGroupSubmitButton').click
      link_element(xpath: "//a[@title='#{group.group_set}']").when_present Utils.short_wait

      # Create new group within the group set
      logger.info "Creating new group called '#{group.title}'"
      js_click button_element(class: 'add-group')
      wait_for_element_and_type(edit_group_name_input_element, group.title)
      button_element(id: 'groupEditSaveButton').click
      link_element(xpath: "//a[contains(.,'#{group.title}')]").when_present Utils.short_wait
      (link = link_element(xpath: "//a[contains(.,'#{group.title}')]/../following-sibling::div[contains(@class,'group-actions')]//a")).when_present Utils.short_wait
      logger.info "Group ID is '#{group.site_id = link.attribute('id').split('-')[1]}'"
    end

    # Deletes a group set
    # @param course [Course]
    # @param group [Group]
    def instructor_delete_grp_set(course, group)
      load_course_grps course
      logger.info "Deleting teacher group set '#{group.group_set}'"
      wait_for_load_and_click link_element(xpath: "//a[@title='#{group.group_set}']")
      wait_for_update_and_click link_element(xpath: '//button[@title="Add Group"]/following-sibling::span/a')
      confirm(true) { wait_for_update_and_click link_element(class: 'delete-category') }
      list_item_element(xpath: '//li[contains(.,"Group set successfully removed")]').when_present Utils.short_wait
    end

    # MESSAGES

    link(:inbox_link, id: 'global_nav_conversations_link')
    button(:msg_delete_button, id: 'delete-btn')
    paragraph(:msg_body, xpath: '//li[@class="message-item-view"]/p')

    # Verifies the existence and content of a message in the Canvas inbox
    # @param from_user [User]
    # @param to_user [User]
    # @param msg [String]
    # @param test_id [String]
    def verify_message(from_user, to_user, msg, test_id)
      wait_for_update_and_click inbox_link_element
      div_element(xpath: "//h2[contains(., '#{from_user.full_name}, #{to_user.full_name}')]/following-sibling::div[contains(., '#{test_id}')]").when_visible Utils.short_wait
      wait_for_update_and_click list_item_element(xpath: "//h2[contains(., '#{from_user.full_name}, #{to_user.full_name}')]/..")
      msg_body_element.when_visible Utils.short_wait
      wait_until(Utils.short_wait, "Expected '#{msg}' but got '#{msg_body}'") { msg_body == msg }
    end

    # Deletes an open Canvas inbox message
    def delete_open_msg
      confirm(true) { wait_for_update_and_click msg_delete_button_element }
    end

  end
end
