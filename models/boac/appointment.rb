class Appointment < TimelineRecord

  attr_accessor :advisor,
                :cancel_reason,
                :cancel_detail,
                :detail,
                :status,
                :status_date,
                :student,
                :type

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
    @topics ||= []
  end

end
