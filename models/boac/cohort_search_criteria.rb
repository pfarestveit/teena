class CohortSearchCriteria

  attr_accessor :squads, :levels, :majors, :gpa_ranges, :units

  def initialize(criteria)
    criteria.each { |k, v| public_send("#{k}=", v) }
  end

end
