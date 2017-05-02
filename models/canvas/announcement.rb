class Announcement

  attr_accessor :title, :body, :url

  def initialize(title, body, url = nil)
    @title = title
    @body = body
    @url = url
  end

end
