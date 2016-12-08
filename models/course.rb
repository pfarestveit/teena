class Course

  attr_accessor :code, :title, :term, :sections, :teachers, :site_id, :create_site_workflow

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
