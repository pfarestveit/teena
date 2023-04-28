class Note < NoteTemplate

  attr_accessor :is_draft,
                :source_body_empty,
                :set_date

  def initialize(note_data)
    super note_data
  end

end
