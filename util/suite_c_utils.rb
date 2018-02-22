require_relative 'spec_helper'

class SuiteCUtils

  include Logging

  @config = Utils.config

  # TIMEOUTS

  # Timeout intended to wait for a Canvas poller cycle to complete
  def self.canvas_poller_wait
    @config['timeouts']['canvas_poller']
  end

  # The file path for SuiteC asset upload files
  # @param file_name [String]
  def self.test_data_file_path(file_name)
    File.join(Utils.config_dir, "suite-c-assets/#{file_name}")
  end

  # Loads file containing test data for SuiteC tests
  def self.load_suitec_test_data
    test_users = File.join(Utils.config_dir, 'test-data-suitec.json')
    (JSON.parse File.read(test_users))['users']
  end

  # Given a SuiteC test script's event object, returns the file path of the event tracking CSV for that object
  # @param event [Event]
  # @return [String]
  def self.events_csv(event)
    spec = Utils.get_test_script_name event.test_script
    File.join(Utils.initialize_test_output_dir, "selenium-suitec-events-#{spec}-#{event.test_id}.csv")
  end

  # Base URL of SuiteC test environment
  def self.suite_c_base_url
    @config['suite_c']['base_url']
  end

  # LTI tool key and secret for SuiteC test environment
  # @return [Hash]
  def self.lti_credentials
    {key: @config['suite_c']['lti_key'], secret: @config['suite_c']['lti_secret']}
  end

  # The number of times to check if the SuiteC poller has synced Canvas course site data and SuiteC data
  def self.poller_retries
    @config['suite_c']['poller_retries']
  end

  # DATABASE

  def self.suitec_db_credentials
    {
      host: @config['suite_c']['db_host'],
      port: @config['suite_c']['db_port'],
      name: @config['suite_c']['db_name'],
      user: @config['suite_c']['db_user'],
      password: @config['suite_c']['db_password']
    }
  end

  # Inactivates all existing courses. Used to stop the poller checking courses other than the one under test.
  def self.inactivate_all_courses
    query = 'UPDATE courses SET active = false;'
    Utils.query_db(suitec_db_credentials, query)
  end

  # Returns a given asset's ID, provided the asset has a unique title
  # @param asset [Asset]
  # @return [String]
  def self.get_asset_id_by_title(asset)
    query = "SELECT id FROM assets WHERE title = '#{asset.title}'"
    id = Utils.query_db_field(suitec_db_credentials, query, 'id').first
    logger.info "Asset ID is #{id}"
    id.to_s
  end

  # Returns a given asset's current impact score
  # @param asset [Asset]
  # @return [Integer]
  def self.get_asset_impact_score(asset)
    query = "SELECT impact_score FROM assets WHERE id = #{asset.id}"
    score = Utils.query_db_field(suitec_db_credentials, query, 'impact_score').first
    score.to_i
  end

  # Returns a given user's SuiteC ID for a course
  # @param user [User]
  # @param course [Course]
  # @return [String]
  def self.get_user_suitec_id(user, course)
    query = "SELECT users.id
             FROM users
             JOIN courses ON users.course_id=courses.id
             WHERE users.canvas_user_id = #{user.canvas_id}
               AND courses.canvas_course_id = #{course.site_id}"
    results = Utils.query_db(suitec_db_credentials, query)
    user.suitec_id = results[0]['id']
  end

end
