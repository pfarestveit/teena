class FilteredCohort < Cohort

  attr_accessor :search_criteria, :member_count

  def initialize(cohort_data)
    cohort_data.each { |k, v| public_send("#{k}=", v) }
  end

end
