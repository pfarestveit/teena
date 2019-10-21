class NoteTemplate < TimelineRecord

  include Logging

  attr_accessor :title,
                :subject,
                :body,
                :attachments

  def self.get_user_note_templates(user)
    query = "SELECT note_templates.id
             FROM note_templates
             JOIN authorized_users ON note_templates.creator_id = authorized_users.id
             WHERE authorized_users.uid = '#{user.uid}'
               AND note_templates.deleted_at IS NULL;"
    ids = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').map &:to_i
    ids.map { |id| NoteTemplate.new(id: id)}
  end

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
    @topics ||= []
    @attachments ||= []
  end

  # Sets and returns a note template ID
  # @return [Integer]
  def get_note_template_id
    query = "SELECT id FROM note_templates WHERE title = '#{@title}';"
    result = Utils.query_pg_db(BOACUtils.boac_db_credentials, query).values.first
    result.first if result
  end

end
