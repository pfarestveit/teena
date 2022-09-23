class DegreeCompletedCourse < DegreeCourse

  attr_accessor :ccn,
                :term_id,
                :grade,
                :note,
                :units_orig,
                :degree_check,
                :junk,
                :req_course,
                :course_copies,
                :course_orig,
                :manual,
                :waitlisted

  def initialize(test_data)
    super
    @course_copies ||= []
  end

end
