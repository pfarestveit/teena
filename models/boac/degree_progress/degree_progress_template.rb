class DegreeProgressTemplate

  attr_accessor :id,
                :name,
                :unit_reqts,
                :column_reqts,
                :created_date,
                :updated_date,
                :deleted_date

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

  def set_new_template_id
    query = "SELECT id FROM degree_progress_templates WHERE degree_name = '#{@name}';"
    @id = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').first
    logger.debug "Template ID is #{@id}"
    @created_date = Date.today
  end

end
