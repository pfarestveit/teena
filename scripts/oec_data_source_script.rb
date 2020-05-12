require 'selenium-webdriver'

begin

  puts "#{Time.now} - Beginning OEC data source update script"
  args = ARGV

  @base_url = if args.include? 'qa'
                'https://course-evaluations-qa.berkeley.edu'
              elsif args.include? 'prod'
                'https://course-evaluations.berkeley.edu'
              else
                puts "#{Time.now} - ERROR! You didn't enter a valid Blue environment to update"
                fail
              end

  # Define data source names in Blue
  data_sources = if args.include? 'campus'
                   [
                       {src: 'Campus_Courses', file_name: 'courses'},
                       {src: 'Campus_Instructors', file_name: 'instructors'},
                       {src: 'Campus_Students', file_name: 'students'},
                       {src: 'Campus_Supervisors', file_name: 'supervisors'},
                       {src: 'Campus_Course_Instructors', file_name: 'course_instructors'},
                       {src: 'Campus_Course_Students', file_name: 'course_students'},
                       {src: 'Campus_Course_Supervisors', file_name: 'course_supervisors'},
                       {src: 'Campus_Department_Hierarchy', file_name: 'department_hierarchy'},
                       {src: 'Campus_Department_Supervisors', file_name: 'report_viewer_hierarchy'}
                   ]
                 elsif args.include? 'haas'
                   [
                       {src: 'Haas-Courses', file_name: 'Haas Courses'},
                       {src: 'Haas-Instructors', file_name: 'Haas Instructors'},
                       {src: 'Haas-Students', file_name: 'Haas Students'},
                       {src: 'Haas-Course_Instructors', file_name: 'Course_Instructors_Haas'},
                       {src: 'Haas-Course_Students', file_name: 'Course_Students_Haas'},
                       {src: 'Haas-Staff', file_name: 'Haas_Staff'},
                   ]
                 elsif args.include? 'extension'
                   [
                       {src: 'UNEX-CE-Courses', file_name: 'UNEX-CE-Courses'},
                       {src: 'UNEX-CE-Users', file_name: 'UNEX-CE-Users'},
                       {src: 'UNEX-CE-Course_Instructor', file_name: 'UNEX-CE-Course_Instructor'},
                       {src: 'UNEX-CE-Course_Student', file_name: 'UNEX-CE-Course_Student'},
                       {src: 'UNEX-CE-Course_Supervisor', file_name: 'UNEX-CE-Course_Supervisor'},
                       {src: 'UNEX-Courses', file_name: 'UNEX-Courses'},
                       {src: 'UNEX-Users', file_name: 'UNEX-Users'},
                       {src: 'UNEX-Course_Instructor', file_name: 'UNEX-Course_Instructor'},
                       {src: 'UNEX-Course_Student', file_name: 'UNEX-Course_Student'},
                       {src: 'UNEX-Course_Supervisor', file_name: 'UNEX-Course_Supervisor'}
                   ]
                 else
                   puts "#{Time.now} - ERROR! You didn't enter a valid data source to update"
                   fail
                 end

  # Associate a file path with each data source, whether local upload or server path
  data_sources.each do |source|

    if args.include? 'upload'
      files = Dir[File.join(ENV['HOME'], "selenium-files/#{source[:file_name]}.#{+ 'csv' || 'CSV'}")]
      source.merge!(file_path: (files.first if files.any?))

    elsif args.include? 'path'
      path = if args.include? 'campus'
               'berkeley'
             elsif args.include? 'haas'
               'BHaas'
             else
               'UNEX'
             end
      source.merge!(file_path: "c:\\shares\\#{path}\\#{source[:file_name]}.csv")
    else
      puts "#{Time.now} - ERROR! You didn't enter a valid update workflow"
      fail
    end
  end

  # Set timeouts and launch browser, optionally headless
  @brief_wait = Selenium::WebDriver::Wait.new(timeout: 30)
  @medium_wait = Selenium::WebDriver::Wait.new(timeout: 120)
  @long_wait = Selenium::WebDriver::Wait.new(timeout: 900)
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument 'headless' if args.include? 'headless'
  @driver = Selenium::WebDriver.for :chrome, options: options

  def scroll_to_element(driver, element)
    driver.execute_script('arguments[0].scrollIntoView(true);', element)
    sleep 1
  end

  def click_element_id(driver, id)
    puts "#{Time.now} - Waiting for an element with ID '#{id}' to appear"
    @brief_wait.until { driver.find_element(id: id) }
    puts "#{Time.now} - Found the element, clicking it"
    scroll_to_element(driver, driver.find_element(id: id))
    driver.find_element(id: id).click
  end

  def switch_to_window
    @driver.switch_to.window @driver.window_handle
  end

  def log_in(args)
    puts "#{Time.now} - Logging in to Blue at #{@base_url}"
    @driver.get "#{@base_url}"
    click_element_id(@driver, 'username')
    username = args.find { |a| a.include? 'username' }
    password = args.find { |a| a.include? 'password' }
    @driver.find_element(id: 'username').send_keys username.gsub('username=', '')
    @driver.find_element(id: 'password').send_keys password.gsub('password=', '')
    click_element_id(@driver, 'submit')
    @medium_wait.until { @driver.find_element(id: 'BlueAppControl_admin-link-btn') }
  end

  def find_and_edit_source(data_source)
    # Load homepage, click Admin button, and click Data Sources
    puts "#{Time.now} - Processing '#{data_source[:src]}'"
    @driver.get @base_url
    click_element_id(@driver, 'BlueAppControl_admin-link-btn')
    click_element_id(@driver, 'AdminUC_menu_item_data_sources')
    # Search for the data source type
    puts "#{Time.now} - Searching for data source"
    @brief_wait.until { @driver.find_element(id: 'AdminUC_DataSources_AdminDataSource_Tabs_MultiDataSource_listing') }
    sleep 2
    @driver.find_element(id: 'AdminUC_DataSources_AdminDataSource_Tabs_tbSearchValue').send_keys data_source[:src]
    click_element_id(@driver, 'AdminUC_DataSources_AdminDataSource_Tabs_btnSearch')
    @brief_wait.until { @driver.find_element(xpath: "//table[@id='AdminUC_DataSources_AdminDataSource_Tabs_MultiDataSource_listing']//tr[3][contains(.,'#{data_source[:src]}')]") }
    scroll_to_element(@driver, @driver.find_element(link_text: 'Edit'))
    @driver.find_element(link_text: 'Edit').click
    # Click Data tab and click Edit on Data Blocks tab
    puts "#{Time.now} - Found data source, editing it"
    click_element_id(@driver, 'AdminUC_Data_primary-tabs_Data')
    @brief_wait.until do
      @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_lblDataSource')
      @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_lblDataSource').text.include? data_source[:src] }
    end
    scroll_to_element(@driver, @driver.find_element(link_text: 'Edit'))
    @driver.find_element(link_text: 'Edit').click
  end

  def upload_file_or_set_path(data_source, args)
    @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_dplConnector') }
    select = Selenium::WebDriver::Support::Select.new @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_dplConnector')
    switch_to_window unless args.include? 'headless'
    if args.include? 'upload'
      puts "#{Time.now} - Uploading file '#{data_source[:file_path]}'"
      select.select_by(:value, 'CSV')
      @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_File1') }
      @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_File1').send_keys data_source[:file_path]
      sleep 5
    else
      puts "#{Time.now} - Entering path '#{data_source[:file_path]}'"
      select.select_by(:value, 'CSVP')
      @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_txtPath') }
      @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_txtPath').clear
      @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_txtPath').send_keys data_source[:file_path]
    end
    click_element_id(@driver, 'AdminUC_Data_ucAdminDS_Entities_btnUpload')
    sleep 5
    @long_wait.until { @driver.find_element(id: 'AdminUC_Data_ucAdminDS_Entities_cbAll') }
  end

  def apply_and_import_source
    # Apply data block update
    puts "#{Time.now} - Applying and importing data source"
    click_element_id(@driver, 'AdminUC_Data_ucAdminDS_Entities_cbAll')
    sleep 2
    @brief_wait.until do
      @driver.find_elements(xpath: '//table[@id="AdminUC_Data_ucAdminDS_Entities_FieldTable"]//input[@type="checkbox"]').each { |e| e.selected? }
    end
    click_element_id(@driver, 'AdminUC_Data_ucAdminDS_Entities_btnAdd')
    @long_wait.until { @driver.find_element(xpath: '//a[contains(.,"Data block updated.")]') }
    sleep 2
    # Import data source
    click_element_id(@driver, 'AdminUC_Data_primary-tabs_ImportExport')
    click_element_id(@driver, 'AdminUC_Data_AdminDS_Import_btnImport')
    @long_wait.until { @driver.find_element(id: 'AdminUC_Data_AdminDS_Import_btnConfirm') }
    click_element_id(@driver, 'AdminUC_Data_AdminDS_Import_btnConfirm')
    @long_wait.until { @driver.find_element(xpath: '//span[contains(.,"Data Import Approved and Successful")]') }
    @brief_wait.until { @driver.find_element(id: 'AdminUC_Data_lnkBackToDataSources') }
    sleep 2
    puts "#{Time.now} - Import succeeded"
  end

  def create_results_file
    output_dir = File.join(ENV['HOME'], 'selenium-files')
    output_file = 'data_source_update_results.log'
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    file = File.join(output_dir, output_file)
    File.open(file, 'w') { |f| f.puts 'Results of OEC data source update script run:' }
    file
  end

  def log_results(file, result, e = nil)
    puts result
    puts "#{e.message}\n#{e.backtrace}" if e
    File.open(file, 'a') do |f|
      f.puts "\n => #{result}"
      f.puts "\n#{e.message}\n#{e.backtrace}" if e
    end
  end

  # Execute data source update

  results_file = create_results_file

  log_in args

  data_sources.each do |source|
    if args.include?('upload') && !source[:file_path]
      puts "#{Time.now} - ERROR! There is no file to upload for #{source[:src]}"
      log_results(results_file, "#{Time.now} - There was no file to upload for data source '#{source[:src]}'. Update failed.")
    else
      begin
        find_and_edit_source source
        upload_file_or_set_path(source, args)
        apply_and_import_source
        log_results(results_file, "#{Time.now} - Update succeeded for #{source[:src]}")
      rescue => e
        log_results(results_file, "#{Time.now} - Encountered an error with data source '#{source[:src]}'. Update failed.", e)
      end
    end
  end

rescue => e
  puts e.message
  puts e.backtrace
ensure
  @driver.quit rescue NoMethodError
end
