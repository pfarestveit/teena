class AdvisorRole

  attr_accessor :code,
                :description

  def initialize(code, description)
    @code = code
    @description = description
  end

  ROLES = [
      DIRECTOR = new('director', 'Director'),
      ADVISOR = new('advisor', 'Advisor'),
      SCHEDULER = new('scheduler', 'Scheduler')
  ]

end
