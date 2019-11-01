class AppointmentStatus

  attr_reader :name

  def initialize(name)
    @name = name
  end

  STATUSES = [
      CANCELED = new('Canceled'),
      CHECKED_IN = new('Checked in'),
      RESERVED = new('Reserved'),
      WAITING = new('Waiting')
  ]

end
