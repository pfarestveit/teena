class Cohort

  attr_accessor :code, :name, :parent_team, :search_criteria

  def initialize(cohort_data)
    cohort_data.each { |k, v| public_send("#{k}=", v) }
  end

end
