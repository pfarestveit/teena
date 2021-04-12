class NoteSource

  attr_accessor :schema, :name

  def initialize(schema, name)
    @schema = schema
    @name = name
  end

  SOURCES = [
      ASC = new('boac_advising_asc', 'ASC'),
      DATA = new('boac_advising_data_science', 'Data Science'),
      E_AND_I = new('boac_advising_e_i', 'CE3'),
      SIS = new('sis_advising_notes', 'SIS')
  ]

end
