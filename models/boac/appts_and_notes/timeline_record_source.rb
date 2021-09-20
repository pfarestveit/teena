class TimelineRecordSource

  attr_accessor :note_schema, :name

  def initialize(name, note_schema, appt_schema)
    @name = name
    @note_schema = note_schema
    @appt_schema = appt_schema
  end

  SOURCES = [
      ASC = new('ASC', 'boac_advising_asc', nil),
      DATA = new('Data Science', 'boac_advising_data_science', nil),
      E_AND_I = new('CE3', 'boac_advising_e_i', nil),
      E_FORM = new('eForm', 'sis_advising_notes', nil),
      SIS = new('SIS', 'sis_advising_notes', nil),
      YCBM = new('YouCanBookMe', nil, 'ycbm_advising_appointments')
  ]

end
