class Note

  attr_accessor :id,
                :subject,
                :body,
                :source_body_empty,
                :advisor_uid,
                :advisor_name,
                :advisor_role,
                :advisor_dept,
                :created_date,
                :updated_date,
                :topics,
                :attachment_files

  def initialize(note_data)
    note_data.each { |k, v| public_send("#{k}=", v) }
  end

end
