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
    link(:success_msg, xpath: '//a[contains(.,"Data block updated.")]')
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
      file_input_element.when_visible Utils.medium_wait
      file_input_element.send_keys file
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

    select_list(:task_type_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_dplTask')
    select_list(:task_status_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_dplStatus')

    select_list(:dept_form_field_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplField1')
    select_list(:dept_form_opr_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplOpr1')
    text_area(:dept_form_search_input, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_txtBox1')

    select_list(:eval_type_field_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplField2')
    select_list(:eval_type_opr_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplOpr2')
    text_area(:eval_type_search_input, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_txtBox2')

    select_list(:catalog_id_field_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplField3')
    select_list(:catalog_id_opr_select, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_dplOpr3')
    text_area(:catalog_id_search_input, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_txtBox3')

    button(:task_filter_button, id: 'BlueAppControl_TopLabelProjectManagement_TaskManagementUC_SearchBox_btnSearch')
    link(:first_fill_out_link, xpath: '//span[text()="Form Fill Out"]/ancestor::td/following-sibling::td[6]/a[contains(.,"Link")]')
    button(:next_button, id: 'FilloutController_btnNext')
    button(:submit_button, id: 'FilloutController_btnSubmit')

    # Searches for a project
    # @param title [String]
    def load_project(title)
      wait_for_load_and_click projects_link_element
      projects_heading_element.when_visible Utils.medium_wait
      wait_for_load_and_click project_search_input_element
      wait_for_element_and_type(project_search_input_element, title)
      link_element(xpath: "//div[text()='#{title}']/ancestor::a").when_visible Utils.medium_wait
      # Invoke 'find_element' by XPath with each interaction to avoid stale element errors
      link_element(xpath: "//div[text()='#{title}']/../../..//a[@title='Manage Project']").when_visible Utils.short_wait
      link_element(xpath: "//div[text()='#{title}']/../../..//a[@title='Manage Project']").click
      task_list_heading_element.when_visible Utils.medium_wait
    end

    # Returns the "total" portion of the tasks results count string
    # @return [Integer]
    def total_results
      parts = results_count.split('of ')
      parts[1].split(' ').first.to_i
    end

    # Waits for the number of results to shrink as filters are applied
    def wait_for_filtered_results
      initial_results = total_results
      tries = 5
      begin
        logger.debug 'Waiting for filtered results'
        wait_until(2) { total_results < initial_results }
      rescue
        (tries -= 1).zero? ? (logger.warn 'Task count is unchanged, moving on.') : retry
      end
    end

    # Searches for a fill-out form type, opens the first in the list, and navigates to the questionnaire
    # @param form [Hash]
    # @return [Integer]
    def search_for_fill_out_form_tasks(form)
      dept = OECDepartments::DEPARTMENTS.find { |d| d.dept_code == form[:dept_code] }
      # A department can use a special form for specific catalog IDs and default form for the rest. Search for tasks for each
      # catalog ID in case any are present for the semester.
      tries = dept.catalog_ids ? dept.catalog_ids.length : 1
      begin
        # Search for the right form type
        wait_for_element_and_select_js(task_type_select_element, 'Form Fill Out')
        wait_for_filtered_results
        wait_for_element_and_select_js(task_status_select_element, 'Not Completed')
        wait_for_filtered_results
        wait_for_element_and_select_js(dept_form_field_select_element, 'DEPT_FORM (Subjects)')
        wait_for_element_and_select_js(dept_form_opr_select_element, 'Is')
        wait_for_element_and_type(dept_form_search_input_element, form[:dept_code])
        wait_for_element_and_select_js(eval_type_field_select_element, 'EVALUATION_TYPE (Subjects)')
        wait_for_element_and_select_js(eval_type_opr_select_element, 'Is')
        wait_for_element_and_type(eval_type_search_input_element, form[:eval_type])

        if dept.catalog_ids
          index = dept.catalog_ids.length - tries
          wait_for_element_and_select_js(catalog_id_field_select_element, 'CATALOG_ID (Subjects)')
          # If this is a special form for catalog IDs, include that search parameter
          if form[:catalog_ids]
            logger.info "Catalog ID is #{form[:catalog_ids][index]}"
            wait_for_element_and_select_js(catalog_id_opr_select_element, 'Is')
            wait_for_element_and_type(catalog_id_search_input_element, form[:catalog_ids][index])
          # If the dept has special forms for catalog IDs but this is the default form, then exclude the catalog ID in the search
          else
            logger.info "Catalog ID is not #{dept.catalog_ids[index]}"
            wait_for_element_and_select_js(catalog_id_opr_select_element, 'Is not')
            wait_for_element_and_type(catalog_id_search_input_element, dept.catalog_ids[index])
          end
        end

        wait_for_update_and_click task_filter_button_element
        wait_for_filtered_results
        wait_until(1, "Visible task count is #{total_results}") { total_results > 0 }
      rescue
        retry unless (tries -= 1).zero?
      ensure
        return total_results
      end
    end

    # Clicks the first task link in the list and navigates to the questionnaire page
    # @param driver [Selenium::WebDriver]
    # @param form [Hash]
    def open_fill_out_form_task(driver, form)
      # Load the form in a new window
      wait_for_update_and_click first_fill_out_link_element
      wait_until(1) { driver.window_handles.length > 1 }
      driver.switch_to.window driver.window_handles.last
      wait_for_load_and_click next_button_element
      div_element(xpath: '//div[contains(@id,"MainQuestionDiv")]').when_visible Utils.medium_wait

      # Take a screenshot of the form
      Utils.save_screenshot(driver, "#{form[:dept_code].delete(',')}_#{form[:eval_type]}")
    end

    # Closes the questionnaire if it is open
    # @param driver [Selenium::WebDriver]
    def close_form(driver)
      if driver.window_handles.length > 1 && submit_button?
        driver.close
        driver.switch_to.window driver.window_handles.first
      end
    end

    # EVALUATION FILL-OUT FORMS

    # Given a questionnaire type, verifies that a given question is actually present in the right location and structure.
    # @param driver [Selenium::WebDriver]
    # @param form [Hash]
    # @param question [Hash]
    def verify_question(driver, form, question)

      def question_div(question, category_heading)
        "//h2[contains(.,'#{category_heading}')]/ancestor::div[contains(@id,'MainQuestionDiv')]/div[contains(@class,'FilloutQuestionListingDiv')][contains(.,\"#{question[:question]}\")]"
      end

      # Get the xpath to the div containing the question
      question_xpath = if question[:category] == 'instructor' && form[:eval_type] == 'G' && form[:dept_code] != 'INTEGBI'
                         question_div(question, 'Feedback for Graduate Student Instructor')
                       elsif question[:category] == 'instructor' && form[:eval_type] == 'G' && form[:dept_code] == 'INTEGBI'
                         question_div(question, 'Feedback for Discussion/Lab Instructor')
                       elsif question[:category] == 'instructor' && form[:eval_type] != 'G'
                         question_div(question, 'Feedback for Instructor')
                       elsif question[:category] == 'course'
                         question_div(question, 'Course-Related Questions')
                       elsif question[:category] == 'student'
                         question_div(question, 'Student Information Questions')
                       elsif question[:category] == 'general'
                         question_div(question, 'General Open-Ended Questions')
                       elsif question[:category] == 'none'
                         "//div[contains(@class,'FilloutQuestionListingDiv')][contains(.,\"#{question[:question]}\")]"
                       else
                         logger.error "Invalid question category: '#{question[:category]}'"
                         fail
                       end

      # Based on the type of question, find the specific element(s) that should contain the question and any associated radio buttons, text inputs, labels
      case question[:type]

        when 'heading'
          verify_block do
            wait_until(2) do
              # Check that the exact heading text is in the right section
              driver.find_element(:xpath => "#{question_xpath}//h2/span[contains(.,\"#{question[:question]}\")]")
              logger.info "Found '#{question[:question]}'"
            end
          end

        when 'radio-horizontal'
          verify_block do
            wait_until(2) do
              # Check that the exact question text is in the right section and that it has the right radio button options
              driver.find_element(:xpath => "#{question_xpath}//table//tr[2]/td/span[text()=\"#{question[:question]}\"]")
              logger.info "Found '#{question[:question]}'"
              question[:options].each do |o|
                cell_node = question[:options].index(o) + 2
                driver.find_element(:xpath => "#{question_xpath}//table//tr[2]/td[#{cell_node}]/label[text()='#{o}']/following-sibling::input")
              end
              # TODO - verify right number of options
            end
          end

        when 'radio-vertical'
          verify_block do
            wait_until(2) do
              # Check that the exact question text is in the right section and that it has the right radio button options
              driver.find_element(:xpath => "#{question_xpath}//a[text()=\"#{question[:question]}\"]")
              logger.info "Found '#{question[:question]}'"
              question[:options].each do |o|
                driver.find_element(:xpath => "#{question_xpath}//div[@class='VerticalQRatingRadioButtonDiv']//label[text()='#{o}']/preceding-sibling::input")
              end
              # TODO - verify right number of options
            end
          end

        when 'checkbox'
          verify_block do
            wait_until(2) do
              # Verify the question heading text
              driver.find_element(:xpath => "#{question_xpath}//h3/a[text()=\"#{question[:question]}\"]")
              logger.info "Found '#{question[:question]}'"

              # Verify the checkboxes and labels
              driver.find_element(:xpath => "#{question_xpath}//label[text()=\"#{question[:sub_question]}\"]/preceding-sibling::input")
              logger.info "Found '#{question[:sub_question]}'"
              # TODO - verify right number of checkboxes
            end
          end

        when 'input'
          verify_block do
            wait_until(2) do

              if question[:sub_type] && question[:sub_type] == 'line-break'
                # Check that the question text appears but don't look for exact match
                driver.find_element(:xpath => "#{question_xpath}//h3/a[contains(., \"#{question[:question]}\")]")
                driver.find_element(:xpath => "#{question_xpath}//h3/a[contains(., \"#{question[:sub_question]}\")]")
                logger.info "Found '#{question[:question]}'"
              else
                # Check that the exact question text is in the right section and that it has an accompanying text input field
                driver.find_element(:xpath => "#{question_xpath}//h3/a[text()=\"#{question[:question]}\"]")
                logger.info "Found '#{question[:question]}'"
              end

              # Some questions have supplemental text on separate lines
              if question[:sub_type] && question[:sub_type] == 'list'
                driver.find_element(:xpath => "#{question_xpath}//span[contains(.,\"#{question[:sub_question]}\")]")
                logger.info "Found '#{question[:sub_question]}'"
              end

              # Two different input elements are in use, so look for the most common one. If not found, check for the other.
              begin
                driver.find_element(:xpath => "#{question_xpath}//textarea")
              rescue
                driver.find_element(:xpath => "#{question_xpath}//input")
              end
            end
          end

        when 'nested'
          verify_block do
            wait_until(2) do
              # Verify the question heading text
              driver.find_element(:xpath => "#{question_xpath}//h3/a[text()=\"#{question[:question]}\"]")
              logger.info "Found '#{question[:question]}'"

              # Verify the nested question text
              driver.find_element(:xpath => "#{question_xpath}//table//tr[contains(.,\"#{question[:sub_question]}\")]/td[2]/span[text()=\"#{question[:sub_question]}\"]")
              logger.info "Found '#{question[:sub_question]}'"
              # TODO - verify right number of sub-questions

              # Verify the radio button labels
              question[:sub_options].each do |o|
                cell_node = question[:sub_options].index(o) + 3
                driver.find_element(:xpath => "#{question_xpath}//table//tr/td[#{cell_node}]/span[text()='#{o}']")
              end
              # TODO - verify right number of options
            end
          end

        when 'drop-down-list-vertical'
          verify_block do
            wait_until(2) do
              # Verify the question heading text
              logger.debug "Checking path: '#{question_xpath}//h3/a[text()=\"#{question[:question]}\"]'"
              driver.find_element(:xpath => "#{question_xpath}//h3/a[text()=\"#{question[:question]}\"]")
              logger.info "Found '#{question[:question]}'"

              # Verify select options
              question[:options].each do |o|
                logger.debug "Checking path: '#{question_xpath}//select/option[text()='#{o}']'"
                driver.find_element(:xpath => "#{question_xpath}//select/option[text()='#{o}']")
              end
            end
          end

        else
          logger.error "Invalid question type: '#{question[:type]}'"
          fail
      end
    end

    elements(:question_div, :div, :class => 'FilloutQuestionListingDiv')

    # Verifies the actual number of sections on a form matches the expected number: one for each question category heading
    # plus one for each question, with instructor category questions expected once per instructor.
    # @param questions [Array<Hash>]
    def verify_question_count(questions)
      verify_block do
        # Determine the expected number of heading sections
        heading_types = questions.map { |q| q[:category] }
        expected_headings = heading_types.uniq.reject { |h| h == 'none' }
        logger.debug "Expected headings are #{expected_headings}"

        # Account for 'nested' questions appearing together in a single section
        unique_questions = questions.uniq { |q| [q[:question], q[:type]] }

        # Account for co-taught course forms showing instructor questions more than once
        instructor_heading_count = h2_elements(:xpath => '//h2[contains(.,"Feedback for ")]').length
        logger.debug "The number of instructors on the form is #{instructor_heading_count}"
        instructor_questions = unique_questions.select { |q| q[:category] == 'instructor' }
        (instructor_heading_count - 1).times do
          expected_headings << 1
          unique_questions << instructor_questions
        end

        # Compare the expected section count to that visible on the form
        visible_question_count = question_div_elements.length
        expected_question_count = expected_headings.length + unique_questions.flatten.length
        logger.info "The number of sections on the form should be #{expected_question_count}"
        wait_until(2, "Expected #{expected_question_count} question divs but got #{visible_question_count}") { visible_question_count == expected_question_count }
      end
    end

  end
end
