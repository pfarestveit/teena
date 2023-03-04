class CourseSite

  attr_accessor :id,
                :abbreviation,
                :course,
                :create_site_workflow,
                :created_date,
                :manual_members,
                :sections,
                :sis_teacher

  def initialize(site_data)
    site_data.each { |k, v| public_send("#{k}=", v) }
  end

  def expected_student_count
    @sections.map(&:enrollments).select { |e| e.status == 'E' }.flatten.length
  end

  def expected_wait_list_count
    @sections.map(&:enrollments).select { |e| e.status == 'W' }.flatten.length
  end

  def expected_teacher_count
    if @sections.map(&:primary).any?
      @sections.map(&:instructors).select { |e| %w(PI ICNT).include? e.role_code }.flatten.uniq.length
    else
      @sections.map(&:instructors).flatten.uniq.length
    end
  end

  def expected_lead_ta_count
    if @sections.map(&:primary).any?
      @sections.map(&:instructors).select { |e| e.role_code == 'APRX' }.flatten.uniq.length
    else
      0
    end
  end

  def expected_ta_count
    if @sections.map(&:primary).any?
      @sections.map(&:instructors).select { |e| e.role_code == 'TNIC' }.flatten.uniq.length
    else
      0
    end
  end
end
