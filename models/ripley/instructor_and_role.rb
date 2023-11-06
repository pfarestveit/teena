class InstructorAndRole

  attr_accessor :user,
                :role_code

  def initialize(user, role_code)
    @user = user
    @role_code = role_code
  end

end
