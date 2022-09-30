class IncompleteGrade

  attr_accessor :code, :descrip

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
  end

  STATUSES = [
    I = new(code: 'I', descrip: 'Incomplete'),
    L = new(code: 'L', descrip: 'Lapsed'),
    R = new(code: 'R', descrip: 'Removed')
  ]

end
