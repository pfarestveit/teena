class Note < NoteTemplate

  attr_accessor :source_body_empty,
                :set_date

  def initialize(note_data)
    super note_data
  end

end
