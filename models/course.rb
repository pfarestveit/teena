class Course

  attr_accessor :code,
                :title,
                :term,
                :sis_id,
                :sections,
                :teachers,
                :site_id,
                :site_created_date,
                :tests,
                :create_site_workflow

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
