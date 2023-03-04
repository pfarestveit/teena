class Course

  attr_accessor :code,
                :create_site_workflow,
                :title,
                :term,
                :sis_id,
                :site_id,
                :sections,
                :teachers

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
