require_relative '../../util/spec_helper'

module Page

  class CanvasGroupsPage < CanvasPage

    include PageObject
    include Logging
    include Page

    def load_course_grps(course_site)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course_site.site_id}/groups"
    end

    def grp_link_el(group)
      link_element(xpath: "//a[contains(.,'#{group.title}')]")
    end

    # INSTRUCTOR

    # Group sets

    button(:grp_set_add_button, id: 'add-group-set')
    text_field(:grp_set_name_input, id: 'new-group-set-name')
    checkbox(:grp_set_self_signup_cbx, xpath: '//input[@data-testid="checkbox-allow-self-signup"]')
    button(:grp_set_save_button, xpath: '//button[@data-testid="group-set-save"]')
    button(:grp_set_actions_button, xpath: '//button[@title="Add Group"]/following-sibling::span/a')
    link(:grp_set_delete_link, xpath: '//a[contains(@class, "delete-category")]')
    element(:grp_set_deleted_msg, xpath: '//*[contains(.,"Group set successfully removed")]')
    link(:stud_grps_link, text: 'Student Groups')

    def grp_set_link_el(group_set)
      link_element(xpath: "//a[@title='#{group_set.title}']")
    end

    def instr_load_stud_grps(course)
      load_course_grps course
      wait_for_update_and_click stud_grps_link_element
    end

    def instr_load_grp_set(course, group_set)
      load_course_grps course
      wait_for_update_and_click grp_set_link_el(group_set)
    end

    def instr_create_grp_set(course, group_set)
      logger.info "Creating new group set called '#{group_set.title}'"
      load_course_grps course
      wait_for_load_and_click grp_set_add_button_element
      wait_for_element_and_type(grp_set_name_input_element, group_set.title)
      js_click grp_set_self_signup_cbx_element
      wait_for_update_and_click grp_set_save_button_element
      grp_set_link_el(group_set).when_present Utils.short_wait
    end

    def instr_delete_grp_set(course, group_set)
      logger.info "Deleting teacher group set '#{group_set}'"
      instr_load_grp_set(course, group_set)
      h2_element(xpath: '//h2[contains(text(), "Unassigned Students")]').when_visible Utils.short_wait
      sleep 3
      wait_for_update_and_click grp_set_actions_button_element
      alert { wait_for_update_and_click grp_set_delete_link_element }
      grp_set_deleted_msg_element.when_present Utils.short_wait
    end

    # Group

    button(:instr_grp_add_button, xpath: '//button[@aria-label="Add Group"]')
    text_field(:instr_grp_name_input, id: 'group_name')
    button(:instr_grp_save_button, xpath: '//button[contains(., "Save")]')

    def grp_actions_button_el(group)
      link_element(xpath: "//a[contains(.,'#{group.title}')]/../following-sibling::div[contains(@class,'group-actions')]//a")
    end

    def assign_stud_link_el(student)
      link_element(xpath: "//a[@aria-label='Assign #{student.full_name} to a group']")
    end

    def assign_grp_link_el(group)
      link_element(xpath: "//a[@data-group-id='#{group.id}']")
    end

    def instr_create_grp(course, group)
      logger.info "Creating new group called #{group.title} within #{group.group_set}"
      instr_load_grp_set(course, group.group_set)
      instr_grp_add_button_element.when_present Utils.short_wait
      sleep 1
      wait_for_update_and_click instr_grp_add_button_element
      wait_for_element_and_type(instr_grp_name_input_element, group.title)
      wait_for_update_and_click instr_grp_save_button_element
      grp_link_el(group).when_present Utils.short_wait
      grp_actions_button_el(group).when_present Utils.short_wait
      group.id = grp_actions_button_el(group).attribute('id').split('-')[1]
      logger.info "Group ID is #{group.id}"
    end

    def instr_add_grp_members(course, group)
      instr_load_grp_set(course, group.group_set)
      group.members.each do |member|
        logger.info "Assigning #{member.full_name} to #{group.title}"
        wait_for_update_and_click assign_stud_link_el(member)
        wait_for_update_and_click assign_grp_link_el(group)
      end
    end

    # STUDENT

    button(:stud_grp_add_button, xpath: '//button[@data-testid="add-group-button"]')
    text_field(:stud_grp_add_name_input, id: 'group-name')
    text_field(:stud_grp_add_member_input, id: 'invite-filter')
    elements(:stud_grp_member_option, :span, xpath: '//span[@role="option"]')
    button(:stud_grp_save_button, xpath: '//button[contains(., "Submit")]')
    element(:stud_joined_grp_msg, xpath: '//*[contains(.,"Joined Group")]')
    element(:stud_left_grp_msg, xpath: '//*[contains(.,"Left Group")]')
    link(:edit_grp_link, id: 'edit_group')
    text_field(:edit_grp_name_input, id: 'group_name')
    button(:edit_grp_save_button, xpath: '//button[@type="submit"]')

    def stud_visit_grp_link_el(group)
      link_element(xpath: "//a[contains(@aria-label, \"Visit group #{group.title}\")]")
    end

    def stud_join_grp_button_el(group)
      button_element(xpath: "//button[contains(@aria-label, \"Join group #{group.title}\")]")
    end

    def stud_leave_grp_button_el(group)
      button_element(xpath: "//button[contains(@aria-label, \"Leave group #{group.title}\")]")
    end

    def stud_switch_grp_button_el(group)
      button_element(xpath: "//button[contains(@aria-label, \"Switch to group #{group.title}\")]")
    end

    def stud_create_grp(course, group)
      logger.info "Student creating student group '#{group.title}'"
      load_course_grps course
      wait_for_update_and_click stud_grp_add_button_element
      wait_for_element_and_type(stud_grp_add_name_input_element, group.title)
      wait_for_update_and_click stud_grp_save_button_element
      stud_visit_grp_link_el(group).when_present Utils.short_wait
      group.id = stud_visit_grp_link_el(group).attribute('href').split('/').last
      logger.info "Group ID is #{group.id}"
    end

    def stud_edit_grp_name(course, group, new_name)
      stud_visit_grp(course, group)
      logger.debug "Changing group title to '#{group.title = new_name}'"
      wait_for_update_and_click edit_grp_link_element
      wait_for_textbox_and_type(edit_grp_name_input_element, group.title)
      wait_for_update_and_click edit_grp_save_button_element
      wait_until(Utils.short_wait) { recent_activity_heading.include? group.title }
      group.title = new_name
    end

    def stud_visit_grp(course, group)
      logger.info "Visiting #{group.title}"
      load_course_grps course
      wait_for_update_and_click stud_visit_grp_link_el(group)
      wait_until(Utils.short_wait) { recent_activity_heading.include? group.title }
    end

    def stud_join_grp(course, group)
      logger.info "Joining #{group.title}"
      load_course_grps course
      wait_for_update_and_click stud_join_grp_button_el(group)
      stud_joined_grp_msg_element.when_present Utils.short_wait
    end

    def stud_switch_grps(course, new_group)
      logger.info "Switching from to #{new_group.title}"
      load_course_grps course
      wait_for_update_and_click stud_switch_grp_button_el(new_group)
      stud_joined_grp_msg_element.when_present Utils.short_wait
    end

    def stud_leave_grp(course, group)
      logger.info "Leaving #{group.title}"
      load_course_grps course
      wait_for_update_and_click stud_leave_grp_button_el(group)
      stud_left_grp_msg_element.when_present Utils.short_wait
    end
  end
end
