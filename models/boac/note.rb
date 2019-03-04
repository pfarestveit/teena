class Note

  attr_accessor :id,
                :category,
                :subcategory,
                :body,
                :advisor_uid,
                :advisor_sid,
                :created_date,
                :updated_date,
                :topics,
                :attachment_files

  def initialize(note_data)
    note_data.each { |k, v| public_send("#{k}=", v) }
  end

end
