class DeptMembership

  attr_accessor :advisor_role,
                :dept,
                :is_automated

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
  end

end
