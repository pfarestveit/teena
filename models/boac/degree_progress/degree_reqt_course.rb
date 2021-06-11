class DegreeReqtCourse < DegreeCourse

  include Logging

  attr_accessor :completed_course,
                :dummy,
                :parent

  def set_id(template_id)
    query = "SELECT id FROM degree_progress_categories WHERE name = '#{@name}' AND template_id = '#{template_id}';"
    @id = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').first
    logger.debug "Course ID is #{@id}"
  end

  def set_dummy_reqt_id
    query = "SELECT id
             FROM degree_progress_categories
             WHERE category_type = 'Placeholder: Course Copy'
               AND parent_category_id = '#{@parent.id}'
               AND name = '#{@completed_course.name}';"
    @id = BOACUtils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').first
    logger.debug "Dummy reqt course id is #{@id}"
  end

end
