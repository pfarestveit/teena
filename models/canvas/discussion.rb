class Discussion

  attr_accessor :title, :url

  def initialize(title, url = nil)
    @title = title
    @url = url
  end

end
