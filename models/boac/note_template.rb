class NoteTemplate

  attr_accessor :id, :title, :subject, :body, :topics, :attachments

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
    @topics ||= []
    @attachments ||= []
  end

end
