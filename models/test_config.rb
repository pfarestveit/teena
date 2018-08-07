class TestConfig

  attr_accessor :id

  def initialize
    @id = Time.now.to_i.to_s
  end

end
