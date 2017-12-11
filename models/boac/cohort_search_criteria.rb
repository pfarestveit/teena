class CohortSearchCriteria

  attr_accessor :squads, :levels, :terms, :gpa, :units

  def initialize(criteria)
    criteria.each { |k, v| public_send("#{k}=", v) }
  end

end
