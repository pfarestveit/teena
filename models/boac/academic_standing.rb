class AcademicStanding

  attr_accessor :code, :descrip, :term_id

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
  end

  STATUSES = [
      DIS = new(code: 'DIS', descrip: 'Dismissed'),
      GST = new(code: 'GST', descrip: 'Good Standing'),
      PRO = new(code: 'PRO', descrip: 'Probation'),
      SUB = new(code: 'SUB', descrip: 'Subject to Dismissal')
  ]

end
