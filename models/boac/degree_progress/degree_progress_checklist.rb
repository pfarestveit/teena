class DegreeProgressChecklist < DegreeProgressTemplate

  attr_accessor :id,
                :student,
                :note,
                :completed_courses

  def initialize(template, student)
    @name = template.name.dup
    @unit_reqts = template.unit_reqts.dup
    @categories = template.categories.dup
    @student = student
  end

  def set_degree_check_ids
    query = "SELECT id FROM degree_progress_templates WHERE degree_name = '#{@name}' AND student_sid = '#{@student.sis_id}';"
    @id = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').first
    logger.debug "Degree check ID is #{@id}"
    @created_date = Date.today

    @unit_reqts && @unit_reqts.each { |units| units.set_id @id }
    @categories && categories.each do |cat|
      cat.set_id @id
      cat.course_reqs && cat.course_reqs.each { |course| course.set_id @id }
      cat.sub_categories && cat.sub_categories.each do |sub|
        sub.set_id @id
        sub.course_reqs && sub.course_reqs.each { |course| course.set_id @id }
      end
    end
  end

end
