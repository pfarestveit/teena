class SquiggyComment

  attr_accessor :user,
                :body

  def initialize(user, body)
    @user = user
    @body = body
  end

end
