require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class MyToolboxPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      image(:conjunction_junction, xpath: '//img[@src="/static/img/conjunction-junction.6e1a4394.jpg"]')

      # Loads My Toolbox
      def load_page
        logger.info 'Loading My Toolbox page'
        navigate_to "#{JunctionUtils.junction_base_url}/toolbox"
      end

      ### VIEW AS ###

      text_field(:view_as_input, id: 'basic-auth-uid')
      button(:view_as_submit_button, id: 'view-as-submit')
      link(:campus_dir_link, id: 'link-to-httpswwwberkeleyedudirectory')

      def view_as_user(user, calnet_page)
        logger.info "Viewing as UID #{user.uid}"
        wait_for_element_and_type(view_as_input_element, user.uid.to_s)
        wait_for_update_and_click view_as_submit_button
        calnet_page.enter_credentials(Utils.super_admin_username, Utils.super_admin_password, 'PLEASE REAUTH MANUALLY')
        stop_viewing_as_button_element.when_visible Utils.short_wait
      end

      # Saved Users

      button(:clear_saved_users_button, id: 'clear-saved-users')
      table(:saved_users,'//h3[text()="Saved Users"]/../../following-sibling::div//table')

      def saved_user_view_as_button(user)
        button_element(xpath: "//h3[text()='Saved Users']/../../following-sibling::div//button[text()=' #{user.uid} ']")
      end

      def saved_user_remove_button(user)
        button_element(id: "remove-user-#{user.uid}")
      end

      def remove_saved_user(user)
        logger.info "Removing saved UID #{user.uid}"
        wait_for_update_and_click saved_user_remove_button(user)
        saved_user_remove_button(user).when_not_present Utils.short_wait
      end

      def clear_saved_users
        logger.info 'Clearing all saved users'
        wait_for_update_and_click clear_saved_users_button_element
      end

      # Recent Users

      button(:clear_recent_users_button, id: 'clear-recent-users')
      table(:recent_users, '//h3[text()="Recent Users"]/../../following-sibling::div//table')

      def recent_user_view_as_button(user)
        button_element(xpath: "//h3[text()='Recent Users']/../../following-sibling::div//button[text()=' #{user.uid} ']")
      end

      def recent_user_save_button(user)
        button_element(id: "save-user-#{user.uid}")
      end

      def save_recent_user(user)
        logger.info "Saving recent UID #{user.uid}"
        wait_for_update_and_click recent_user_save_button(user)
        wait_until(Utils.short_wait) do
          saved_users?
          saved_user_remove_button(user).exists?
        end
      end

      def clear_recent_users
        logger.info 'Clearing all recent users'
        wait_for_update_and_click clear_recent_users_button_element
      end

      ### OEC ###

      select_list(:oec_task_select, id: 'cc-page-oec-task')
      select_list(:oec_term_select, id: 'cc-page-oec-term')
      select_list(:oec_dept_select, id: 'cc-page-oec-department')
      button(:oec_show_depts_button, id: 'show-participating-departments')
      elements(:oec_dept, :list_item, xpath: '//ul[contains(@class, "participating-list")]/li')
      button(:oec_run_task_button, id: 'oec-run-task-button')

      def select_task(name)
        logger.info "Selecting the '#{name}' OEC task"
        wait_for_element_and_select_js(oec_task_select_element, name)
      end

      def visible_oec_task_options
        wait_for_update_and_click oec_task_select_element unless oec_task_select_options.any?
        opts = oec_task_select_options
        opts.delete 'Select task...'
        opts
      end

      def visible_oec_dept_options
        oec_dept_select_options
      end

      def toggle_oec_depts_visibility
        wait_for_update_and_click oec_show_depts_button_element
      end

      def visible_participating_depts
        oec_dept_elements.map &:text
      end

    end
  end
end
