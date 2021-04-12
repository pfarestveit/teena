class DegreeProgressPerm

  attr_reader :desc

  def initialize(desc)
    @desc = desc
  end

  PERMS = [
    READ = new('Read-only'),
    WRITE = new('Read and write')
  ]

end
