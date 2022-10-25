class SquiggyUser < User

  attr_accessor :score

  def initialize(test_data)
    super
    @score ||= 0
  end

end
