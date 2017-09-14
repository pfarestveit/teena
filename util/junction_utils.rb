require_relative 'spec_helper'

class JunctionUtils

  include Logging

  # JUNCTION

  # Base URL of Junction test environment
  def self.junction_base_url
    @config['junction']['base_url']
  end

  # Basic auth password for CalCentral test environments
  def self.junction_basic_auth_password
    @config['junction']['basic_auth_password']
  end

  # Loads file containing test date for course-driven bCourses tests
  def self.load_junction_test_data
    test_data_file = File.join(ENV['HOME'], '/.webdriver-config/test-data-bcourses.json')
    JSON.parse(File.read(test_data_file))
  end

  # Loads test data for course-driven bCourses tests
  def self.load_junction_test_course_data
    load_junction_test_data['courses']
  end

  # Loads test data for user-driven bCourses tests
  def self.load_junction_test_user_data
    load_junction_test_data['users']
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
    my_toolbox_page.log_out splash_page
  end

  # Creates CSV for data generated during Junction test runs
  # @param spec [RSpec::ExampleGroups]
  # @param column_headers [Array]
  # @return [File]
  def self.initialize_junction_test_output(spec, column_headers)
    output_file = "#{spec.inspect.sub('RSpec::ExampleGroups::', '')}.csv"
    logger.info "Initializing test output CSV named #{output_file}"
    test_output = File.join(initialize_test_output_dir, output_file)
    CSV.open(test_output, 'wb') { |heading| heading << column_headers }
    test_output
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

end
