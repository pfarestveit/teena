require_relative '../../util/spec_helper'

module Page

  class CanvasGroupsPage < CanvasPage

    include PageObject
    include Logging
    include Page

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
      alert { wait_for_update_and_click link_element(class: 'delete-category') }
      list_item_element(xpath: '//li[contains(.,"Group set successfully removed")]').when_present Utils.short_wait
    end

  end
end
