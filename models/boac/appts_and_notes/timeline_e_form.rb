class TimelineEForm < TimelineRecord

  attr_accessor :form_id,
                :term,
                :course,
                :action,
                :status,
                :units_taken,
                :requested_units_taken

  def initialize(e_form_data)
    e_form_data.each { |k, v| public_send("#{k}=", v) }
  end

end
