class Whiteboard

  attr_accessor :id, :owner, :title, :collaborators

  def initialize(whiteboard_data)
    whiteboard_data.each { |k, v| public_send("#{k}=", v) }
  end

end
