class Email

  attr_accessor :subject, :body

  def initialize(subject, body)
    @subject = subject
    @body = body
  end

end
