class Term

  attr_accessor :code,
                :name,
                :sis_id

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
