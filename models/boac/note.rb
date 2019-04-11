class Note

  attr_accessor :id,
                :subject,
                :body,
                :source_body_empty,
                :advisor,
                :topics,
                :attachments,
                :created_date,
                :updated_date,
                :deleted_date

  def initialize(note_data)
    note_data.each { |k, v| public_send("#{k}=", v) }
    @topics ||= []
    @attachments ||= []
  end

end
