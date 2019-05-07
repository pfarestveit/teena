class BOACDepartments

  attr_accessor :code, :name

  def initialize(code, name)
    @code = code
    @name = name
  end

  DEPARTMENTS = [
      ADMIN = new('ADMIN', 'Admin'),
      ASC = new('UWASC', 'Athletic Study Center'),
      COE = new('COENG', 'College of Engineering'),
      L_AND_S = new('QCADV', 'College of Letters & Science'),
      PHYSICS = new('PHYSI', 'Department of Physics')
  ]

end
