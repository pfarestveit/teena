class NoteBatch < Note

  attr_accessor :students, :cohorts, :curated_groups

  def initialize(note_data)
    super note_data
    @students ||= []
    @cohorts ||= []
    @curated_groups ||= []
  end

end
