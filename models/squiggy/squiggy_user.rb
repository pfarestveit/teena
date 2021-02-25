class SquiggyUser < User

  attr_accessor :squiggy_id,
                :assets

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
