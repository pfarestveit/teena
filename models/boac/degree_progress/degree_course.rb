class DegreeCourse

  attr_accessor :id,
                :name,
                :units,
                :units_reqts,
                :grade,
                :term,
                :note

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
