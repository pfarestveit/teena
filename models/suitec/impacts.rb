class Impacts

  attr_accessor :points

  def initialize(points)
    @points = points
  end

  GET_VIEW = new(1)
  GET_LIKE = new(1.5)
  GET_PIN = new(2.5)
  GET_COMMENT = new(3)
  GET_REPLY = new(3)
  GET_WHITEBOARD_USE = new(4)
  GET_WHITEBOARD_REMIX = new(5)

  class << self
    private :new
  end

end
