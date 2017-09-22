require_relative '../../util/spec_helper'

class Comment

  attr_accessor :user, :body

  def initialize(user, body)
    @user = user
    @body = body
  end

end
