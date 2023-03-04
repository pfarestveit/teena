class Section

  attr_accessor :id,
                :course,
                :enrollments,
                :include_in_site,
                :instructors,
                :label,
                :locations,
                :primary,
                :schedules,
                :sis_id

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
