class DegreeCourse

  include Logging

  attr_accessor :id,
                :column_num,
                :junk,
                :name,
                :units,
                :units_reqts

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

  def set_id(template_id)
    query = "SELECT id FROM degree_progress_categories WHERE name = '#{@name}' AND template_id = '#{template_id}';"
    @id = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').first
    logger.debug "Course ID is #{@id}"
  end

end
