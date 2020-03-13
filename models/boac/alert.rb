class Alert

  attr_accessor :id, :user, :type, :message, :date

  def initialize(alert_data)
    alert_data.each { |k, v| public_send("#{k}=", v) }
  end

end
