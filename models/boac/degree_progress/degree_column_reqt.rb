class DegreeColumnReqt

  attr_accessor :id,
                :name,
                :desc,
                :column_index

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
