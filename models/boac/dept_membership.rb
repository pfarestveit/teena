class DeptMembership

  attr_accessor :advisor_role,
                :dept,
                :is_automated,
                :is_drop_in_advisor,
                :is_drop_in_available,
                :drop_in_status

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
  end

end
