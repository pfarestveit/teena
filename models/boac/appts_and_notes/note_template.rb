class NoteTemplate < TimelineNoteAppt

  include Logging

  attr_accessor :is_private

  def initialize(template_data)
    template_data.each { |k, v| public_send("#{k}=", v) }
    @is_private ||= false
    @topics ||= []
    @attachments ||= []
  end

  def self.get_user_note_templates(user)
    query = "SELECT note_templates.id
             FROM note_templates
             JOIN authorized_users ON note_templates.creator_id = authorized_users.id
             WHERE authorized_users.uid = '#{user.uid}'
               AND note_templates.deleted_at IS NULL;"
    ids = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').map &:to_i
    ids.map { |id| NoteTemplate.new(id: id) }
  end

  # Sets and returns a note template ID
  # @return [Integer]
  def get_note_template_id
    query = "SELECT id FROM note_templates WHERE title = '#{@title}';"
    result = Utils.query_pg_db(BOACUtils.boac_db_credentials, query).values.first
    result.first if result
  end

  def hard_delete_template
    sql = "DELETE FROM note_templates WHERE id = '#{@id}'"
    Utils.query_pg_db(BOACUtils.boac_db_credentials, sql)
  end

end
