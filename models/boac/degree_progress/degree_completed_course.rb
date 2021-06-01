class DegreeCompletedCourse < DegreeCourse

  attr_accessor :ccn,
                :req_course,
                :grade,
                :note,
                :term_id,
                :units_orig,
                :course_copies,
                :course_orig

  def initialize(test_data)
    super
    @course_copies ||= []
  end

end
