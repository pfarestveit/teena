class Section

  attr_accessor :id,
                :course,
                :cs_course_id,
                :enrollments,
                :include_in_site,
                :instruction_mode,
                :instructors,
                :label,
                :locations,
                :number,
                :primary,
                :primary_assoc_id,
                :schedules,
                :sis_id

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
