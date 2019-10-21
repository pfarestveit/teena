class Appointment < TimelineRecord

  attr_accessor :advisor,
                :canceled_date,
                :cancel_reason,
                :cancel_detail,
                :checked_in_date,
                :detail,
                :student,
                :type

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
    @topics ||= []
  end

end
