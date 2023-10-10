class CourseSite

  attr_accessor :abbreviation,
                :course,
                :create_site_workflow,
                :created_date,
                :is_copy,
                :manual_members,
                :sections,
                :test_teacher,
                :site_id,
                :term,
                :title

  def initialize(site_data)
    site_data.each { |k, v| public_send("#{k}=", v) }
  end

  def expected_student_count
    enrolled = @sections.map(&:enrollments).flatten.select { |e| e.status == 'E' }
    enrolled.map { |e| e.user.sis_id }.uniq.length
  end

  # TODO account for students both confirmed and waitlisted
  def expected_wait_list_count
    wait_listed = @sections.map(&:enrollments).flatten.select { |e| e.status == 'W' }
    wait_listed.map { |w| w.user.sis_id }.uniq.length
  end

  def expected_teacher_count
    instructors = @sections.map(&:instructors).flatten
    if @sections.map(&:primary).any?
      instructors.select { |i| %w(PI ICNT).include? i.role_code }.uniq { |i| i.user.uid }.length
    else
      instructors.uniq { |i| i.user.uid }.length
    end
  end

  def expected_lead_ta_count
    if @sections.map(&:primary).any?
      @sections.map(&:instructors).flatten.select { |i| i.role_code == 'APRX' }.uniq { |i| i.user.uid }.length
    else
      0
    end
  end

  def expected_ta_count
    if @sections.map(&:primary).any?
      @sections.map(&:instructors).flatten.select { |i| i.role_code == 'TNIC' }.uniq { |i| i.user.uid }.length
    else
      0
    end
  end
end
