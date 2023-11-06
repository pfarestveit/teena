class Course

  attr_accessor :code,
                :multi_course,
                :sections,
                :sis_id,
                :teachers,
                :term,
                :title

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
