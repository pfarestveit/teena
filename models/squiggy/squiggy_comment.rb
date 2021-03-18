class SquiggyComment

  attr_accessor :asset,
                :body,
                :id,
                :user

  def initialize(comment_data)
    comment_data.each { |k, v| public_send("#{k}=", v) }
  end

end
