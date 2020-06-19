class NoteSource

  attr_accessor :schema

  def initialize(schema)
    @schema = schema
  end

  SOURCES = [
      ASC = new('boac_advising_asc'),
      DATA = new('boac_advising_data_science'),
      E_AND_I = new('boac_advising_e_i'),
      SIS = new('sis_advising_notes')
  ]

end
