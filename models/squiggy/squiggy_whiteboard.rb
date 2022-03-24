class SquiggyWhiteboard

  attr_accessor :id,
                :title,
                :owner,
                :collaborators,
                :asset_exports

  def initialize(whiteboard_data)
    whiteboard_data.each { |k, v| public_send("#{k}=", v) }
    @asset_exports ||= []
  end

end
