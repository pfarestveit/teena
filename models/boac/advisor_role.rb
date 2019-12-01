class AdvisorRole

  attr_accessor :dept,
                :is_advisor,
                :is_automated,
                :is_available,
                :is_director,
                :is_drop_in_advisor,
                :is_scheduler

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
  end

end
