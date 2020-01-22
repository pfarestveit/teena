class AdvisorDropInStatus

  attr_accessor :description

  def initialize(description)
    @description = description
  end

  STATUSES = [
      OFF_DUTY_NO_WAITLIST = new('off_duty_no_waitlist'),
      OFF_DUTY_WAITLIST = new('off_duty_waitlist'),
      ON_DUTY_ADVISOR = new('on_duty_advisor'),
      ON_DUTY_SUPERVISOR = new('on_duty_supervisor')
  ]

end
