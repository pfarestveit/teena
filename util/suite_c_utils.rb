require_relative 'spec_helper'

class SuiteCUtils

  include Logging

  # TIMEOUTS

  # Timeout intended to wait for a Canvas poller cycle to complete
  def self.canvas_poller_wait
    @config['timeouts']['canvas_poller']
  end

  # The file path for SuiteC asset upload files
  # @param file_name [String]
  def self.test_data_file_path(file_name)
    File.join(ENV['HOME'], "/.webdriver-config/suite-c-assets/#{file_name}")
  end

  # Loads file containing test data for SuiteC tests
  def self.load_suitec_test_data
    test_users = File.join(ENV['HOME'], '/.webdriver-config/test-data-suitec.json')
    (JSON.parse File.read(test_users))['users']
  end

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

  # The number of times to drag the event drops in order to bring a metaball into view
  def self.event_drop_drags
    @config['suite_c']['event_drops_drags']
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

  # Returns a given asset's ID, provided the asset has a unique title
  # @param asset [Asset]
  # @return [String]
  def self.get_asset_id_by_title(asset)
    query = "SELECT id FROM assets WHERE title = '#{asset.title}'"
    id = Utils.query_db_field(suitec_db_credentials, query, 'id').first
    logger.info "Asset ID is #{id['id']}"
    id['id'].to_s
  end

  # Returns a given asset's current impact score
  # @param asset [Asset]
  # @return [Integer]
  def self.get_asset_impact_score(asset)
    query = "SELECT impact_score FROM assets WHERE id = #{asset.id}"
    score = Utils.query_db_field(suitec_db_credentials, query, 'impact_score').first
    score['impact_score'].to_i
  end

end
