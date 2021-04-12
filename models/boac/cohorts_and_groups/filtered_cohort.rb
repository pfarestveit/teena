class FilteredCohort < Cohort

  attr_accessor :search_criteria, :member_count, :history

  def initialize(cohort_data)
    cohort_data.each { |k, v| public_send("#{k}=", v) }
    @history ||= []
  end

end
