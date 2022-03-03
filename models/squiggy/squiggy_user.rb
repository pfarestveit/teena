class SquiggyUser < User

  attr_accessor :squiggy_id,
                :score

  def initialize(test_data)
    super
    @score ||= 0
  end

end
