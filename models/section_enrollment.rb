class SectionEnrollment

  attr_accessor :user,
                :grade,
                :grading_basis,
                :section_id,
                :status,
                :term

    def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
