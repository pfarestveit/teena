class BOACDepartments

  attr_accessor :code, :name

  def initialize(code, name)
    @code = code
    @name = name
  end

  DEPARTMENTS = [
      ASC = new('UWASC', 'Athletic Study Center'),
      COE = new('COENG', 'College of Engineering')
  ]

end
