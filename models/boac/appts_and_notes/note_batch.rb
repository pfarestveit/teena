class NoteBatch < Note

  attr_accessor :cohorts,
                :curated_groups,
                :students

  def initialize(note_data)
    super note_data
    @cohorts ||= []
    @curated_groups ||= []
    @students ||= []
  end

end
