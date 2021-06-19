class SquiggyComment

  include Logging

  attr_accessor :asset,
                :body,
                :id,
                :user

  def initialize(comment_data)
    comment_data.each { |k, v| public_send("#{k}=", v) }
    sleep(1)
    @body ||= Time.now.to_i.to_s
  end

  def set_comment_id
    query = "SELECT id FROM comments WHERE body = '#{@body}'"
    id = Utils.query_pg_db_field(SquiggyUtils.db_credentials, query, 'id').first
    logger.info "Comment ID is #{id}"
    @id = id.to_s
  end

end
