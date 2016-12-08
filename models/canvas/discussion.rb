class Discussion

  attr_accessor :title, :date, :url

  def initialize(title, date, url = nil)
    @title = title
    @date = date
    @url = url
  end

end
