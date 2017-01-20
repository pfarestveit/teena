class Course

  attr_accessor :code, :title, :term, :sections, :teachers, :gsis, :site_id, :tests, :create_site_workflow

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
