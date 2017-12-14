class Cohort

  attr_accessor :id, :code, :name, :parent_team, :search_criteria, :owner_uid

  def initialize(cohort_data)
    cohort_data.each { |k, v| public_send("#{k}=", v) }
  end

end
