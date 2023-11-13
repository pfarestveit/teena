class CourseSiteRole

  attr_accessor :name

  def initialize(name)
    @name = name
  end

  ROLES = [
    TEACHER = new('Teacher'),
    LEAD_TA = new('Lead TA'),
    TA = new('TA'),
    READER = new('Reader'),
    DESIGNER = new('Designer'),
    OBSERVER = new('Observer'),
    STUDENT = new('Student'),
    WAITLIST_STUDENT = new('Waitlist Student'),
    OWNER = new('Owner'),
    MAINTAINER = new('Maintainer'),
    MEMBER = new('Member')
  ]

end
