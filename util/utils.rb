require 'hash_deep_merge'
require_relative 'spec_helper'

class Utils

  include Logging

  # Initiate hash (before YAML load) to leverage 'hash_deep_merge' gem. The deep_merge support allows the YAML file in
  # your HOME directory to override a child property (e.g., 'timeouts.short') and yet hold on to sibling properties
  # (e.g., 'timeouts.long') in the default YAML. A standard Hash.merge would cause us to lose the entire parent
  # structure ('timeouts') in the default YAML.
  @config = {}
  @config.merge! YAML.load_file File.path('settings.yml')
  @config.deep_merge! YAML.load_file File.join(ENV['HOME'], '/.webdriver-config/settings.yml')

  # BROWSER CONFIGS

  # Instantiates the browser and alters default browser settings.
  def self.launch_browser
    driver = @config['webdriver']
    logger.info "Launching #{driver.capitalize}"
    if %w(firefox chrome safari).include? driver
      if driver == 'firefox'
        profile = Selenium::WebDriver::Firefox::Profile.new
        profile['browser.download.folderList'] = 2
        profile['browser.download.manager.showWhenStarting'] = false
        profile['browser.download.dir'] = Utils.download_dir
        profile['browser.helperApps.neverAsk.saveToDisk'] = 'application/msword, application/vnd.ms-excel, application/vnd.ms-powerpointtd>, application/pdf, application/zip, audio/mpeg, image/png, image/bmp, image/jpeg, image/gif, image/sgi, image/svg+xml, image/webp, text/csv, video/mp4, video/quicktime'
        driver = Selenium::WebDriver.for :firefox, profile: profile
      elsif driver == 'chrome'
        profile = Selenium::WebDriver::Chrome::Profile.new
        profile['download.prompt_for_download'] = false
        profile['download.default_directory'] = Utils.download_dir
        profile['profile.password_manager_enabled'] = false
        profile['credentials_enable_service'] = false
        profile['password_manager_enabled'] = false
        driver = Selenium::WebDriver.for :chrome, profile: profile
      else
        driver = Selenium::WebDriver.for :safari
      end
      driver.manage.window.maximize
      driver
    else
      logger.error 'Designated WebDriver is not supported'
      nil
    end
  end

  # @param driver [Selenium::WebDriver]
  def self.quit_browser(driver)
    logger.info 'Quitting the browser'
    # If the browser did not start successfully, the quit method will fail.
    driver.quit rescue NoMethodError
    # Pause after quitting the browser to make sure it shuts down completely before the next test relaunches it
    sleep 2
  end

  # Base URL of CalNet authentication service test instance
  def self.cal_net_url
    @config['cal_net']['base_url']
  end

  # Short timeout intended for things like page DOM updates
  def self.short_wait
    @config['timeouts']['short']
  end

  # Moderate timeout intended for things like page loads
  def self.medium_wait
    @config['timeouts']['medium']
  end

  # Long timeout intended for things like large file uploads or asynchronous processes
  def self.long_wait
    @config['timeouts']['long']
  end

  # TEST DATA, UPLOADS, AND DOWNLOADS

  # Returns the current datetime for use as a unique test identifier
  def self.get_test_id
    "#{Time.now.strftime('%Y-%m-%d %H:%M')}"
  end

  # Loads file containing test date for course-driven tests
  def self.load_test_courses
    test_data_file = File.join(ENV['HOME'], '/.webdriver-config/testCourses.json')
    JSON.parse(File.read(test_data_file))['courses']
  end

  # Loads file containing test data for user-driven tests
  def self.load_test_users
    test_users = File.join(ENV['HOME'], '/.webdriver-config/testUsers.json')
    (JSON.parse File.read(test_users))['users']
  end

  # Creates CSV for data generated during Canvas test runs
  # @param spec [RSpec::ExampleGroups]
  # @param column_headers [Array]
  # @return [File]
  def self.initialize_canvas_test_output(spec, column_headers)
    output_dir = File.join(ENV['HOME'], '/tmp/test-output')
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    output_file = "#{spec.inspect.sub('RSpec::ExampleGroups::', '')}.csv"
    logger.info "Initializing test output CSV named #{output_file}"
    test_output = File.join(output_dir, output_file)
    CSV.open(test_output, 'wb') { |heading| heading << column_headers }
    test_output
  end

  # Adds a row of data to Canvas CSV
  # @param file [File]
  # @param values [String]
  def self.add_csv_row(file, values)
    CSV.open(file, 'a+') { |row| row << values }
  end

  # The file path for SuiteC asset upload files
  # @param file_name [String]
  def self.test_data_file_path(file_name)
    File.join(ENV['HOME'], "/.webdriver-config/suite-c-assets/#{file_name}")
  end

  # The directory where files are downloaded during test runs
  def self.download_dir
    File.join(ENV['HOME'], '/tmp/downloads')
  end

  # Prepares a directory to receive files downloaded during test runs
  # @param dir [File]
  def self.prepare_download_dir
    FileUtils::mkdir_p download_dir
    FileUtils.rm_rf(download_dir, secure: true)
  end

  # SUITE C

  # Base URL of SuiteC test environment
  def self.suite_c_base_url
    @config['suite_c']['base_url']
  end

  # LTI tool key for SuiteC test environment
  def self.suitec_lti_key
    @config['suite_c']['lti_key']
  end

  # LTI tool secret for SuiteC test environment
  def self.suitec_lti_secret
    @config['suite_c']['lti_secret']
  end

  # The number of times to check if the SuiteC poller has synced Canvas course site data and SuiteC data
  def self.poller_retries
    @config['suite_c']['poller_retries']
  end

  # CANVAS

  # Base URL of Canvas test environment
  def self.canvas_base_url
    @config['canvas']['base_url']
  end

  # Canvas 'Admin' sub-account ID
  def self.canvas_admin_sub_account
    @config['canvas']['admin_sub_account']
  end

  # Canvas 'Official Courses' sub-account ID
  def self.canvas_official_courses_sub_account
    @config['canvas']['official_courses_sub_account']
  end

  # Canvas 'QA' sub-account ID
  def self.canvas_qa_sub_account
    @config['canvas']['qa_sub_account']
  end

  # Canvas ID of create course site tool
  def self.canvas_create_site_tool
    @config['canvas']['create_site_tool']
  end

  # Canvas ID of course add user tool
  def self.canvas_course_add_user_tool
    @config['canvas']['course_add_user_tool']
  end

  # Canvas ID of course captures tool
  def self.canvas_course_captures_tool
    @config['canvas']['course_captures_tool']
  end

  # Canvas ID of roster photos tool
  def self.canvas_rosters_tool
    @config['canvas']['rosters_tool']
  end

  # Canvas ID of course official sections tool
  def self.canvas_official_sections_tool
    @config['canvas']['official_sections_tool']
  end

  # Canvas ID of admin mailing lists tool
  def self.canvas_mailing_lists_tool
    @config['canvas']['mailing_lists_tool']
  end

  # Canvas ID of instructor mailing list tool
  def self.canvas_mailing_list_tool
    @config['canvas']['mailing_list_tool']
  end

  # Canvas ID of e-grades export tool
  def self.canvas_e_grades_export_tool
    @config['canvas']['e_grades_export_tool']
  end

  # JUNCTION

  # Base URL of Junction test environment
  def self.junction_base_url
    @config['junction']['base_url']
  end

  # Basic auth password for CalCentral test environments
  def self.junction_basic_auth_password
    @config['junction']['basic_auth_password']
  end

  # Authenticates in Junction as an admin and expires all cache
  # @param driver [Selenium::WebDriver]
  # @param splash_page [Page::JunctionPages::SplashPage]
  # @param my_toolbox_page [Page::JunctionPages::MyToolboxPage]
  def self.clear_cache(driver, splash_page, my_toolbox_page)
    splash_page.load_page
    splash_page.basic_auth @config['junction']['admin_uid']
    driver.get("#{junction_base_url}/api/cache/clear")
    sleep 3
    my_toolbox_page.load_page
    my_toolbox_page.click_log_out_link
  end

  # TEST ACCOUNTS

  def self.super_admin_username
    @config['users']['super_admin_username']
  end

  def self.super_admin_password
    @config['users']['super_admin_password']
  end

  def self.super_admin_uid
    @config['users']['super_admin_uid']
  end

  def self.ets_qa_username
    @config['users']['ets_qa_username']
  end

  def self.ets_qa_password
    @config['users']['ets_qa_password']
  end

  def self.test_user_password
    @config['users']['test_user_password']
  end

  # SCREENSHOTS

  def self.save_screenshot(driver, unique_id, uid)
    output_dir = File.join(ENV['HOME'], '/tmp/screenshots')
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    driver.save_screenshot File.join(output_dir, "#{unique_id}-UID#{uid}.png")
  end

end
