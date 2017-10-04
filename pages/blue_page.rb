require_relative '../util/spec_helper'

module Page

  class BluePage

    include PageObject
    include Page
    include Logging

    button(:admin_link_button, id: 'BlueAppControl_admin-link-btn')

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

    def load_home_page(args)
      navigate_to OecUtils.base_url(args)
    end

    def wait_for_log_in(args, cal_net_page)
      load_home_page args
      wait_for_load_and_click cal_net_page.username_element
      admin_link_button_element.when_present Utils.long_wait
    end

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

  end
end
