class DegreeCheck

  attr_accessor :id,
                :name,
                :created_date,
                :updated_date

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
