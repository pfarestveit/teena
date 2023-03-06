class SectionEnrollment

  attr_accessor :uid,
                :section_id,
                :grading_basis,
                :status,
                :units

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
