class BOACTestConfig

  attr_accessor :id, :dept, :advisor, :term, :all_dept_students, :cohort, :cohort_members, :max_cohort_members

  def initialize(test_config)
    test_config.each { |k, v| public_send("#{k}=", v) }
  end

end
