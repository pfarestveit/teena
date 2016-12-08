class Assignment

  attr_accessor :title, :due_date, :url

  def initialize(title, due_date, url = nil)
    @title = title
    @due_date = due_date
    @url = url
  end

end
