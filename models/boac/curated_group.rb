class CuratedGroup < Cohort

  def initialize(cohort_data)
    cohort_data.each { |k, v| public_send("#{k}=", v) }
  end

end
