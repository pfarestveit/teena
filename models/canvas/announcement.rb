class Announcement

  attr_accessor :title, :body, :date, :url

  def initialize(title, body, date, url = nil)
    @title = title
    @body = body
    @date = date
    @url = url
  end

end
