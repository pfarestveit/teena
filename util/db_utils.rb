require_relative 'spec_helper'

class DBUtils

  include Logging

  # Queries the SuiteC db using a given query string and returns the values in a given field
  # @param query_string [String]
  # @param field [String]
  # @return [String]
  def self.query_db_field(query_string, field)
    results = []
    begin
      logger.debug 'Connecting to SuiteC db'
      connection = PG.connect(host: Utils.db_host, port: Utils.db_port, dbname: Utils.db_name, user: Utils.db_user, password: Utils.db_password)
      logger.debug "Sending query '#{query_string}'"
      results = connection.exec query_string
      results.field_values(field)
    rescue PG::Error => e
      Utils.log_error e
    ensure
      connection.close if connection
      return results
    end
  end

  # Returns a given asset's ID, provided the asset has a unique title
  # @param asset [Asset]
  # @return [String]
  def self.get_asset_id_by_title(asset)
    query = "SELECT id FROM assets WHERE title = '#{asset.title}'"
    id = query_db_field(query, 'id').first
    logger.info "Asset ID is #{id['id']}"
    id['id'].to_s
  end

  # Returns a given asset's current impact score
  # @param asset [Asset]
  # @return [Integer]
  def self.get_asset_impact_score(asset)
    query = "SELECT impact_score FROM assets WHERE id = #{asset.id}"
    score = query_db_field(query, 'impact_score').first
    score['impact_score'].to_i
  end
end
