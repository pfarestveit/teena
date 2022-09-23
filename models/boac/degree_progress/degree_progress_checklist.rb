class DegreeProgressChecklist < DegreeProgressTemplate

  attr_accessor :id,
                :student,
                :note,
                :completed_courses

  def initialize(template, student)
    @completed_courses ||= []

    def init_transfer_course(course_reqt)
      course = DegreeCompletedCourse.new(name: course_reqt.name,
                                         grade: 'P',
                                         manual: true,
                                         transfer_course: true,
                                         units: course_reqt.units,
                                         units_reqts: course_reqt.units_reqts)
      course_reqt.completed_course = course
      course.req_course = course_reqt
      course
    end

    @name = template.name.dup
    @unit_reqts = template.unit_reqts.dup
    @unit_reqts.each { |req| req.units_completed = 0 }
    @categories = template.categories.dup
    @categories&.each do |cat|
      cat.course_reqs&.each { |course| @completed_courses << init_transfer_course(course) if course.transfer_course }
      cat.sub_categories && cat.sub_categories.each do |sub|
        sub.course_reqs && sub.course_reqs.each { |course| @completed_courses << init_transfer_course(course) if course.transfer_course }
      end
    end
    @student = student
  end

  def set_degree_check_ids
    query = "SELECT id FROM degree_progress_templates WHERE degree_name = '#{@name}' AND student_sid = '#{@student.sis_id}';"
    @id = Utils.query_pg_db_field(BOACUtils.boac_db_credentials, query, 'id').first
    logger.debug "Degree check ID is #{@id}"
    @created_date = Date.today

    @unit_reqts && @unit_reqts.each { |units| units.set_id @id }
    @categories && @categories.each do |cat|
      cat.set_id @id
      cat.course_reqs && cat.course_reqs.each { |course| course.set_id @id }
      cat.sub_categories && cat.sub_categories.each do |sub|
        sub.set_id @id
        sub.course_reqs && sub.course_reqs.each { |course| course.set_id @id }
      end
    end
  end

end
