class BOACDepartments

  attr_accessor :code, :name, :notes_only

  def initialize(code, name, notes_only=nil)
    @code = code
    @name = name
    @notes_only = notes_only
  end

  DEPARTMENTS = [
      ADMIN = new('ADMIN', 'Admins'),
      ASC = new('UWASC', 'Athletic Study Center'),
      CHEM = new('CDCDN', 'College of Chemistry'),
      COE = new('COENG', 'College of Engineering'),
      ENV_DESIGN = new('DACED', 'College of Environmental Design'),
      GUEST = new('GUEST', 'Guest Access'),
      HAAS = new('BAHSB', 'Haas School of Business'),
      L_AND_S = new('QCADV', 'L&S College Advising'),
      L_AND_S_MAJ = new('QCADVMAJ', 'L&S Major Advising'),
      NAT_RES = new('MANRD', 'College of Natural Resources'),
      NOTES_ONLY = new('NOTESONLY', 'Notes Only', true),
      OTHER = new('ZZZZZ', 'Other')
  ]

end
