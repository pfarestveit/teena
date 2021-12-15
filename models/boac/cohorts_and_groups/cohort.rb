class Cohort

  attr_accessor :id, :name, :ce3, :owner_uid, :members, :member_data, :export_csv

  def initialize(cohort_data)
    cohort_data.each { |k, v| public_send("#{k}=", v) }
    @members ||= []
    @ce3 ||= false
  end

end
