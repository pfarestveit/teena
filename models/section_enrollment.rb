class SectionEnrollment

  attr_accessor :user,
                :term,
                :section_id,
                :grade,
                :grading_basis,
                :status

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
