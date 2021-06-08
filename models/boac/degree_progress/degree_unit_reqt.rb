class DegreeUnitReqt

  include Logging

  attr_accessor :id,
                :name,
                :unit_count,
                :units_completed

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

  def set_id(template_id)
    query = "SELECT id FROM degree_progress_unit_requirements WHERE name = '#{@name}' AND template_id = '#{template_id}';"
    @id = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').first
    logger.debug "Unit requirement ID is #{@id}"
  end

end
