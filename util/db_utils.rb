require_relative 'spec_helper'

class DBUtils

  include Logging

  # Queries a given database using a query string and returns the results
  # @param db_credentials [Hash]
  # @param query_string [String]
  # @return [PG::Result]
  def self.query_db(db_credentials, query_string)
    results = []
    begin
      connection = PG.connect(host: db_credentials[:host], port: db_credentials[:port], dbname: db_credentials[:name], user: db_credentials[:user], password: db_credentials[:password])
      logger.debug "Sending query '#{query_string}'"
      results = connection.exec query_string
    rescue PG::Error => e
      Utils.log_error e
    ensure
      connection.close if connection
      return results
    end
  end

  # Queries a database and returns the values in a given field
  # @param query_string [String]
  # @param field [String]
  # @return [String]
  def self.query_db_field(db_credentials, query_string, field)
    results = query_db(db_credentials, query_string)
    results.field_values(field)
  end

  # SUITE C

  # Returns a given asset's ID, provided the asset has a unique title
  # @param asset [Asset]
  # @return [String]
  def self.get_asset_id_by_title(asset)
    query = "SELECT id FROM assets WHERE title = '#{asset.title}'"
    id = query_db_field(Utils.suitec_db_credentials, query, 'id').first
    logger.info "Asset ID is #{id['id']}"
    id['id'].to_s
  end

  # Returns a given asset's current impact score
  # @param asset [Asset]
  # @return [Integer]
  def self.get_asset_impact_score(asset)
    query = "SELECT impact_score FROM assets WHERE id = #{asset.id}"
    score = query_db_field(Utils.suitec_db_credentials, query, 'impact_score').first
    score['impact_score'].to_i
  end

  # LRS

  # Checks the LRS for the presence of a given event
  # @param event [Event]
  # @return [boolean]
  def self.lrs_event_present?(event)
    event_time = Time.parse(event.time_str).getgm
    min_time_range = (event_time - Utils.event_time_discrep_seconds).strftime('%Y-%m-%d %H:%M:%S')
    max_time_range = (event_time + Utils.event_time_discrep_seconds).strftime('%Y-%m-%d %H:%M:%S')
    query = "SELECT statements.timestamp, users.external_id, statements.activity_type, statements.uuid
             FROM users
             INNER JOIN statements ON users.id=statements.user_id
             WHERE users.external_id = '#{event.actor.uid}'
               AND statements.activity_type = '#{event.action.desc}'
               AND statements.timestamp BETWEEN TIMESTAMP '#{min_time_range}' AND TIMESTAMP '#{max_time_range}';"
    event_rows = []
    results = query_db(Utils.lrs_db_credentials, query)
    results.each { |row| event_rows << {uid: row['external_id'], event_type: row['activity_type'], time: row['timestamp']} }
    logger.info "Event rows obtained from the db are '#{event_rows}'"
    event_rows.length == 1 ? true : false
  end
end
