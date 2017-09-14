require_relative 'spec_helper'

class LRSUtils

  include Logging

  @config = Utils.config

  # Returns the number of times to loop through LRS events scripts
  # @return [Integer]
  def self.script_loops
    @config['lrs']['script_loops']
  end

  # The possible discrepancy between the timestamp a test script assigns an event and the timestamp Canvas assigns the event
  # @return [Integer]
  def self.event_time_discrep_seconds
    @config['lrs']['event_time_discrep_seconds']
  end

  def self.lrs_db_credentials
    {
      host: @config['lrs']['db_host'],
      port: @config['lrs']['db_port'],
      name: @config['lrs']['db_name'],
      user: @config['lrs']['db_user'],
      password: @config['lrs']['db_password']
    }
  end

  # Creates a CSV for analytics events data generated during certain test runs
  # @param script [String]
  # @return [File]
  def self.initialize_events_csv(script)
    output_file = "selenium-events-#{script}-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.csv"
    logger.info "Initializing test output CSV named #{output_file}"
    test_output = File.join(Utils.initialize_test_output_dir, output_file)
    CSV.open(test_output, 'wb') { |heading| heading << %w(Time Actor Action Object) }
    test_output
  end

  # Converts the data on an events CSV row to an event object
  # @param row [CSV::Row]
  # @return [Event]
  def self.events_csv_row_to_event(row)
    event_time_str = row['Time']
    event_actor = User.new({uid: row['Actor']})
    event_action = EventType::EVENT_TYPES.find { |t| t.desc == row['Action'] }
    event_object = row['Object']
    Event.new({time_str: event_time_str, actor: event_actor, action: event_action, object: event_object})
  end

  # Checks the LRS for the presence of a unique event
  # @param event [Event]
  # @return [boolean]
  def self.lrs_event_present?(event)
    event_time = Time.parse(event.time_str).getgm
    min_time_range = (event_time - event_time_discrep_seconds).strftime('%Y-%m-%d %H:%M:%S')
    max_time_range = (event_time + event_time_discrep_seconds).strftime('%Y-%m-%d %H:%M:%S')
    query = "SELECT statements.timestamp, users.external_id, statements.activity_type, statements.statement
             FROM users
             INNER JOIN statements ON users.id=statements.user_id
             WHERE users.external_id = '#{event.actor.uid}'
               AND statements.activity_type = '#{event.action.desc}'
               AND statements.timestamp BETWEEN TIMESTAMP '#{min_time_range}' AND TIMESTAMP '#{max_time_range}';"
    event_rows = []
    results = Utils.query_db(lrs_db_credentials, query)
    results.each { |row| event_rows << {uid: row['external_id'], event_type: row['activity_type'], time: row['timestamp'], json: row['statement']} }
    # If the event has an object, make sure the Caliper statement includes that object
    event_rows = event_rows.select { |row| row[:json].include? event.object } if event.object
    event_rows.length == 1
  end

  # Verifies that each event recorded by a test script is uniquely present in the LRS db, logs the result for each, and fails if any are not
  # @param event [Event]
  def self.verify_canvas_events(event)
    test_results = []
    CSV.foreach(event.csv, :headers => true) do |row|
      event = events_csv_row_to_event row
      logger.info "Checking the event data for #{event.actor.uid} performing a #{event.action.desc} event at approx #{event.time_str}"
      test_results << [[event.time_str, event.actor.uid, event.action.desc, event.object], lrs_event_present?(event)]
     end
    test_results.each { |result| logger.warn "Test result: #{result}" }
    failures = test_results.keep_if { |result| !result[1] }
    fail if failures.any?
  end

end
