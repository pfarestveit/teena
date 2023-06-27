class Course

  attr_accessor :code,
                :create_site_workflow,
                :roster,
                :title,
                :term,
                :sis_id,
                :site_id,
                :sections,
                :site_created_date,
                :teachers,
                :tests

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
