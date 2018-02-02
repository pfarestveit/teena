class Cohort

  attr_accessor :id, :name, :search_criteria, :owner_uid, :member_count

  def initialize(cohort_data)
    cohort_data.each { |k, v| public_send("#{k}=", v) }
  end

end
