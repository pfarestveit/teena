class Appointment < TimelineNoteAppt

  attr_accessor :cancel_reason,
                :cancel_detail,
                :detail,
                :reserve_advisor,
                :status,
                :status_date,
                :start_time,
                :end_time,
                :type

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
    @topics ||= []
  end

end
