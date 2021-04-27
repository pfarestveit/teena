class DegreeReqtCategory

  include Logging

  attr_accessor :id,
                :name,
                :desc,
                :column_num,
                :courses,
                :parent,
                :sub_categories

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
    @column_num = @parent.column_num if @parent
  end

  def set_id(template_id)
    query = "SELECT id FROM degree_progress_categories WHERE name = '#{@name}' AND template_id = '#{template_id}';"
    @id = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').first
    logger.debug "Category ID is #{@id}"
  end

end
