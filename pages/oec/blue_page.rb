require_relative '../../util/spec_helper'

module Page

  class BluePage

    include PageObject
    include Page
    include Logging

    button(:admin_link_button, id: 'BlueAppControl_admin-link-btn')

    # Navigates to the Blue homepage
    # @param args [String]
    def load_home_page(args = nil)
      navigate_to OecUtils.base_url(args)
    end

    # Logs in to Blue
    def log_in(cal_net_page)
      load_home_page
      cal_net_page.log_in(Utils.ets_qa_username, Utils.ets_qa_password)
    end

    def wait_for_log_in(args, cal_net_page)
      load_home_page args
      wait_for_load_and_click cal_net_page.username_element
      admin_link_button_element.when_present Utils.long_wait
    end

    # DATA SOURCE UPDATES

    link(:data_sources_link, id: 'AdminUC_menu_item_data_sources')
    table(:data_sources_table, id: 'AdminUC_DataSources_AdminDataSource_Tabs_MultiDataSource_listing')
    text_area(:data_sources_search_input, id: 'AdminUC_DataSources_AdminDataSource_Tabs_tbSearchValue')
    button(:data_sources_search_button, id: 'AdminUC_DataSources_AdminDataSource_Tabs_btnSearch')
    link(:data_source_edit_link, text: 'Edit')

    link(:data_source_data_tab, id: 'AdminUC_Data_primary-tabs_Data')
    span(:data_blocks_label, id: 'AdminUC_Data_ucAdminDS_Entities_lblDataSource')
    text_area(:file_input, id: 'AdminUC_Data_ucAdminDS_Entities_File1')
    button(:connect_button, id: 'AdminUC_Data_ucAdminDS_Entities_btnUpload')
    checkbox(:select_all_fields_cbx, id: 'AdminUC_Data_ucAdminDS_Entities_cbAll')
    elements(:field_cbx, :checkbox, xpath: '//table[@id="AdminUC_Data_ucAdminDS_Entities_FieldTable"]//input[@type="checkbox"]')

    button(:apply_button, id: 'AdminUC_Data_ucAdminDS_Entities_btnAdd')
    link(:success_msg, xpath: '//a[contains(.,"Data Block has been updated successfully.")]')
    link(:import_export_tab, id: 'AdminUC_Data_primary-tabs_ImportExport')
    button(:import_button, id: 'AdminUC_Data_AdminDS_Import_btnImport')
    button(:import_confirm_button, id: 'AdminUC_Data_AdminDS_Import_btnConfirm')
    span(:import_success_msg, xpath: '//span[contains(.,"Data Import Approved and Successful")]')
    link(:back_to_data_sources_link, id: 'AdminUC_Data_lnkBackToDataSources')

    def find_and_edit_source(args, data_source)
      # Load homepage, click Admin button, and click Data Sources
      logger.info "Processing '#{data_source}'"
      load_home_page args
      wait_for_load_and_click admin_link_button_element
      wait_for_load_and_click data_sources_link_element

      # Search for the data source type
      logger.info 'Searching for data source'
      data_sources_table_element.when_visible Utils.short_wait
      sleep 2
      wait_for_element_and_type(data_sources_search_input_element, data_source)
      wait_for_update_and_click data_sources_search_button_element
      wait_until(Utils.short_wait) { span_element(xpath: "//table[@id='AdminUC_DataSources_AdminDataSource_Tabs_MultiDataSource_listing']//tr[3][contains(.,'#{data_source}')]").exists? }
      wait_for_update_and_click data_source_edit_link_element

      # Click Data tab and click Edit on Data Blocks tab
      logger.info 'Found data source, editing it'
      wait_for_update_and_click data_source_data_tab_element
      wait_until(Utils.short_wait) { data_blocks_label.include? data_source }
      wait_for_update_and_click data_source_edit_link_element
    end

    def upload_file(file)
      logger.info "Uploading file '#{file}'"
      wait_for_element_and_type(file_input_element, file)
      sleep 2
      wait_for_update_and_click connect_button_element
      sleep 5
      select_all_fields_cbx_element.when_present Utils.long_wait
    end

    def connect_source
      logger.info 'Connecting data source'
      wait_for_update_and_click connect_button_element
      sleep 2
      select_all_fields_cbx_element.when_present Utils.short_wait
    end

    def apply_and_import_source
      # Apply data block update
      logger.info 'Applying and importing data source'
      wait_for_update_and_click select_all_fields_cbx_element
      sleep 2
      wait_until(Utils.short_wait) do
        field_cbx_elements.each { |e| e.attribute('checked') == 'checked' }
      end
      wait_for_update_and_click apply_button_element
      success_msg_element.when_present Utils.long_wait
      sleep 2

      # Import data source
      wait_for_update_and_click import_export_tab_element
      wait_for_update_and_click import_button_element
      import_confirm_button_element.when_present Utils.long_wait
      wait_for_update_and_click import_confirm_button_element
      import_success_msg_element.when_present Utils.long_wait
      back_to_data_sources_link_element.when_present Utils.short_wait
      sleep 2
      logger.info 'Import succeeded'
    end

    # PROJECTS

    link(:projects_link, xpath: '//span[text()="Projects"]/ancestor::a')
    div(:projects_heading, xpath: '//div[text()="My Projects"]')
    text_area(:project_search_input, :class => 'search-field')
    link(:manage_project_link, xpath: '//a[@title="Manage Project"]')
    span(:task_list_heading, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_lblTaskList')
    span(:results_count, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_ucBlueGrid_lblTopPageStatus')
    select(:task_type_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_dplTask')
    select(:dept_form_field_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplField1')
    select(:dept_form_opr_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplOpr1')
    text_area(:dept_form_search_input, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_txtBox1')
    select(:eval_type_field_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplField2')
    select(:eval_type_opr_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplOpr2')
    text_area(:eval_type_search_input, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_txtBox2')
    button(:task_filter_button, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_btnSearch')
    link(:first_fill_out_link, xpath: '//span[text()="Form Fill Out"]/ancestor::td/following-sibling::td[6]/a[contains(.,"Link")]')
    button(:next_button, id: 'FilloutController_btnNext')

    # Searches for a project
    # @param title [String]
    def load_project(title)
      logger.info "Loading project named '#{title}'"
      wait_for_load_and_click projects_link_element
      projects_heading_element.when_visible Utils.medium_wait
      wait_for_load_and_click project_search_input_element
      wait_for_element_and_type(project_search_input_element, title)
      link_element(xpath: "//div[text()='#{title}']/ancestor::a").when_visible Utils.medium_wait
      wait_for_update_and_click manage_project_link_element
      task_list_heading_element.when_visible Utils.medium_wait
    end

    # Returns the "total" portion of the tasks results count string
    # @return Integer
    def total_results
      parts = results_count.split('of ')
      ttl = parts[1].split(' ').first.to_i
      logger.debug "Results table shows #{ttl} tasks"
      ttl
    end

    # Waits for the number of results to shrink as filters are applied
    def wait_for_filtered_results
      initial_results = total_results
      tries = 5
      begin
        wait_until(2) { total_results < initial_results }
      rescue => e
        logger.error "#{e.message}"
        (tries -= 1).zero? ? fail : retry
      end
    end

    # Searches for a fill-out form type, opens the first in the list, and navigates to the questionnaire
    # @param driver [Selenium::WebDriver]
    # @param dept_form [String]
    # @param eval_type [String]
    def find_and_open_fill_out_form(driver, dept_form, eval_type)
      # Search for the right form type
      wait_for_element_and_select_js(task_type_select_element, 'Form Fill Out')
      wait_for_filtered_results
      wait_for_element_and_select_js(dept_form_field_select_element, 'DEPT_FORM (Subjects)')
      wait_for_element_and_select_js(dept_form_opr_select_element, 'Is')
      wait_for_element_and_type(dept_form_search_input_element, dept_form)
      wait_for_element_and_select_js(eval_type_field_select_element, 'EVALUATION_TYPE (Subjects)')
      wait_for_element_and_select_js(eval_type_opr_select_element, 'Is')
      wait_for_element_and_type(eval_type_search_input_element, eval_type)
      wait_for_update_and_click task_filter_button_element
      wait_for_filtered_results

      # Load the form in a new window
      wait_for_update_and_click first_fill_out_link_element
      wait_until(1) { driver.window_handles.length > 1 }
      driver.switch_to.window driver.window_handles.last
      wait_for_load_and_click next_button_element
    end

  end
end
