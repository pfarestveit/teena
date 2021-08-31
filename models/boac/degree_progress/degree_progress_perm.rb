class DegreeProgressPerm

  attr_reader :desc

  def initialize(desc, user_perm)
    @desc = desc
    @user_perm = user_perm
  end

  PERMS = [
    READ = new('Read-only', 'Degree Progress (read)'),
    WRITE = new('Read and write', 'Degree Progress (read/write)')
  ]

end
