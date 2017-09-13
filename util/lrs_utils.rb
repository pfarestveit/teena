require_relative 'spec_helper'

class LRSUtils

  include Logging

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

  # Verifies that each event recorded by a test script is uniquely present in the LRS db, logs the result for each, and fails if any are not
  # @param event [Event]
  def self.verify_canvas_events(event)
    test_results = []
    CSV.foreach(event.csv, :headers => true) do |row|
      event = events_csv_row_to_event row
      logger.info "Checking the event data for #{event.actor.uid} performing a #{event.action.desc} event at approx #{event.time_str}"
      test_results << [event, DBUtils.lrs_event_present?(event)]
     end
    test_results.each { |result| logger.warn "Test result: #{result}" }
    failures = test_results.keep_if { |result| !result[1] }
    fail if failures.any?
  end

end
