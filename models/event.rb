class Event

  attr_accessor :csv, :time, :actor, :action, :object

  def initialize(event_data)
    event_data.each { |k, v| public_send("#{k}=", v) }
  end

end
