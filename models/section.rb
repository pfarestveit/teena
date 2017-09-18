class Section

  attr_accessor :course, :label, :id, :sis_id, :schedules, :locations, :include_in_site

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
