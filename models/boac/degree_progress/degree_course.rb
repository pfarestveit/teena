class DegreeCourse

  include Logging

  attr_accessor :id,
                :color,
                :column_num,
                :name,
                :transfer_course,
                :units,
                :units_reqts

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
