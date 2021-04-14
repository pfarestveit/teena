class DegreeProgressTemplate

  attr_accessor :id,
                :name,
                :unit_reqts,
                :categories,
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

  def set_template_content(test_id)
    @name = "#{@name} #{test_id}"

    @unit_reqts = @unit_reqts && @unit_reqts.map do |units|
      DegreeUnitReqt.new name: "#{units['name']} #{test_id}",
                         unit_count: units['unit_count']
    end

    @categories = @categories && @categories.map do |cat|
      DegreeReqtCategory.new name: "#{cat['name']} #{test_id}",
                             desc: cat['desc'],
                             column_index: cat['column_index'],
                             courses: (cat['courses'] && (cat['courses'].map do |course|
                               DegreeCourse.new name: course['name'],
                                                units: course['units'],
                                                units_reqts: course['units_reqts']
                             end)),
                             sub_categories: (cat['sub_categories'] && (cat['sub_categories'].map do |sub|
                               DegreeReqtCategory.new name: "#{sub['name']} #{test_id}",
                                                      desc: sub['desc'],
                                                      courses: (sub['courses'] && (sub['courses'].map do |sub_course|
                                                        DegreeCourse.new name: sub_course['name'],
                                                                         units: sub_course['units'],
                                                                         units_reqts: sub_course['units_reqts']
                                                      end))
                             end))
    end
  end

end
