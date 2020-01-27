class AdvisorRole

  attr_accessor :description

  def initialize(description)
    @description = description
  end

  ROLES = [
      DIRECTOR = new('Director'),
      ADVISOR = new('Advisor'),
      SCHEDULER = new('Scheduler')
  ]

end
