class DeptMembership

  attr_accessor :dept,
                :is_automated,
                :is_advisor,
                :is_drop_in_advisor,
                :drop_in_available,
                :is_director,
                :is_scheduler

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
  end

end
