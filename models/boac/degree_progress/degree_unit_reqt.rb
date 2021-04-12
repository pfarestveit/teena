class DegreeUnitReqt

  attr_accessor :id,
                :name,
                :unit_count

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
