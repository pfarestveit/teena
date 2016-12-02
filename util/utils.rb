require_relative 'spec_helper'

class Utils

  include Logging

  default_settings = YAML.load_file File.path('settings.yml')
  override_settings = YAML.load_file File.join(ENV['HOME'], '/.webdriver-config/settings.yml')
  @config = default_settings.merge! override_settings

  # BROWSER CONFIGS

  # Instantiates the browser. In the case of Firefox, also modifies the default profile to handle downloads
  def self.launch_browser
    driver = @config['webdriver']
    logger.info "Launching #{driver.capitalize}"
    if driver == 'firefox'
      profile = Selenium::WebDriver::Firefox::Profile.new
      profile['browser.download.folderList'] = 2
      profile['browser.download.manager.showWhenStarting'] = false
      profile['browser.download.dir'] = Utils.download_dir
      profile['browser.helperApps.neverAsk.saveToDisk'] = 'application/msword, application/vnd.ms-excel, application/vnd.ms-powerpointtd>, application/pdf, application/zip, audio/mpeg, image/png, image/bmp, image/jpeg, image/gif, image/sgi, image/svg+xml, image/webp, text/csv, video/mp4, video/quicktime'
      driver = Selenium::WebDriver.for :firefox, :profile => profile
      driver.manage.window.maximize
      driver
    elsif driver == 'chrome'
      Selenium::WebDriver.for :chrome
    elsif driver == 'safari'
      Selenium::WebDriver.for :safari
    else
      logger.error 'Designated WebDriver is not supported'
      nil
    end
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

  # Load file containing test course data for Canvas tests
  def self.load_canvas_courses
    test_data_file = File.join(ENV['HOME'], '/.webdriver-config/canvasCourses.json')
    JSON.parse(File.read(test_data_file))['courses']
  end

  # Create CSV for data generated during Canvas test runs
  # @param spec [RSpec::ExampleGroups]
  # @param column_headers [Array]
  # @return [File]
  def self.initialize_canvas_test_output(spec, column_headers)
    output_dir = File.join(ENV['HOME'], '/tmp/test_output')
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    output_file = "#{spec.inspect.sub('RSpec::ExampleGroups::', '')}.csv"
    logger.info "Initializing test output CSV named #{output_file}"
    test_output = File.join(output_dir, output_file)
    CSV.open(test_output, 'wb') { |heading| heading << column_headers }
    test_output
  end

  # Add a row of data to Canvas CSV
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

  # Prepare a directory to receive files downloaded during test runs
  # @param dir [File]
  def self.prepare_download_dir(dir)
    FileUtils::mkdir_p dir
    FileUtils.rm_rf(dir, secure: true)
  end

  # SUITE C

  # Base URL of SuiteC test environment
  def self.suite_c_base_url
    @config['suite_c']['base_url']
  end

  # LTI tool key for SuiteC test environment
  def self.lti_key
    @config['suite_c']['lti_key']
  end

  # LTI tool secret for SuiteC test environment
  def self.lti_secret
    @config['suite_c']['lti_secret']
  end

  # Cartridge XML path for Asset Library LTI tool
  def self.asset_library_xml
    @config['suite_c']['asset_library_xml']
  end

  # Cartridge XML path for Engagement Index LTI tool
  def self.engagement_index_xml
    @config['suite_c']['engagement_index_xml']
  end

  # Cartridge XML path for Whiteboards LTI tool
  def self.whiteboards_xml
    @config['suite_c']['whiteboards_xml']
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

  # Canvas 'QA' sub-account ID
  def self.canvas_sub_account
    @config['canvas']['sub_account']
  end

  # CALCENTRAL

  # Base URL of CalCentral test environment
  def self.calcentral_base_url
    @config['calcentral']['base_url']
  end

  # Basic auth password for CalCentral test environments
  def self.calcentral_basic_auth_password
    @config['calcentral']['basic_auth_password']
  end

end
