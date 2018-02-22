class Event

  attr_accessor :test_script, :test_id, :csv, :time_str, :actor, :action, :object

  def initialize(event_data)
    event_data.each { |k, v| public_send("#{k}=", v) }
  end

end
