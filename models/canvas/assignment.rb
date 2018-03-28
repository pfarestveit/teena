class Assignment

  attr_accessor :id, :type, :title, :url, :due_date, :submitted, :submission_date, :on_time, :graded

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
