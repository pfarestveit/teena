class Note < NoteTemplate

  attr_accessor :source_body_empty

  def initialize(note_data)
    super note_data
  end

end
