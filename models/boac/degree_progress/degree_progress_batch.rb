class DegreeProgressBatch

  attr_accessor :template, :students, :cohorts, :curated_groups

  def initialize(template)
    @template = template
    @students ||= []
    @cohorts ||= []
    @curated_groups ||= []
  end

end
