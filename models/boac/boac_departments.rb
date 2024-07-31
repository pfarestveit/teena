class BOACDepartments

  attr_accessor :code, :name, :export_name, :notes_only

  def initialize(code, name, export_name, notes_only=nil)
    @code = code
    @name = name
    @export_name = export_name
    @notes_only = notes_only
  end

  DEPARTMENTS = [
      ADMIN = new('ADMIN', 'Admins', nil),
      ASC = new('UWASC', 'Athletic Study Center', nil),
      CDSS = new('DSDDO', 'College of Computing, Data Science, and Society', nil),
      CHEM = new('CDCDN', 'College of Chemistry', nil),
      COE = new('COENG', 'College of Engineering', nil),
      ENV_DESIGN = new('DACED', 'College of Environmental Design', nil),
      GUEST = new('GUEST', 'Guest Access', 'Guest'),
      HAAS = new('BAHSB', 'Haas School of Business', nil),
      L_AND_S = new('QCADV', 'College of Letters & Science', 'L&S College Advising'),
      L_AND_S_MAJ = new('QCADVMAJ', 'Letters & Science Major Advisors', 'L&S Major Advising'),
      NAT_RES = new('MANRD', 'College of Natural Resources', nil),
      NOTES_ONLY = new('NOTESONLY', 'Notes Only', nil, true),
      OTHER = new('ZZZZZ', 'Other', nil),
      ZCEEE = new('ZCEEE', 'Centers for Educational Equity and Excellence', nil)
  ]

end
