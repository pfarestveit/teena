class GroupSet

  attr_accessor :id,
                :title,
                :groups,
                :site_id

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
