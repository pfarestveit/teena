class CourseSite

  attr_accessor :abbreviation,
                :course,
                :create_site_workflow,
                :created_date,
                :is_copy,
                :manual_members,
                :sections,
                :site_id,
                :term,
                :title

  def initialize(site_data)
    site_data.each { |k, v| public_send("#{k}=", v) }
  end

  def expected_student_count
    enrolled = @sections.map(&:enrollments).flatten.select { |e| e.status == 'E' }
    enrolled.map(&:sid).uniq.length
  end

  # TODO account for students both confirmed and waitlisted
  def expected_wait_list_count
    wait_listed = @sections.map(&:enrollments).flatten.select { |e| e.status == 'W' }
    wait_listed.map(&:sid).uniq.length
  end

  def expected_teacher_count
    if @sections.map(&:primary).any?
      @sections.map(&:instructors).flatten.select { |e| %w(PI ICNT).include? e.role_code }.uniq.length
    else
      @sections.map(&:instructors).flatten.uniq.length
    end
  end

  def expected_lead_ta_count
    if @sections.map(&:primary).any?
      @sections.map(&:instructors).flatten.select { |e| e.role_code == 'APRX' }.uniq.length
    else
      0
    end
  end

  def expected_ta_count
    if @sections.map(&:primary).any?
      @sections.map(&:instructors).flatten.select { |e| e.role_code == 'TNIC' }.uniq.length
    else
      0
    end
  end
end
