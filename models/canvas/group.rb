class Group

  attr_accessor :title, :members, :group_set, :site_id

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
