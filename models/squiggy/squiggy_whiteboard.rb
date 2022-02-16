class SquiggyWhiteboard

  attr_accessor :id,
                :title,
                :owner,
                :collaborators

  def initialize(whiteboard_data)
    whiteboard_data.each { |k, v| public_send("#{k}=", v) }
  end

end
