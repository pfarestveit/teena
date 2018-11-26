class CuratedGroup < Cohort

  attr_accessor :members

  def initialize(cohort_data)
    cohort_data.each { |k, v| public_send("#{k}=", v) }
    @members ||= []
  end

end
