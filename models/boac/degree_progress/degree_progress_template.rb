class DegreeProgressTemplate

  include Logging

  attr_accessor :id,
                :name,
                :unit_reqts,
                :categories,
                :updated_by,
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

    @unit_reqts = @unit_reqts&.map do |units|
      DegreeUnitReqt.new name: "#{units['name']} #{test_id}",
                         unit_count: units['unit_count']
    end

    @categories = @categories&.map do |cat|
      DegreeReqtCategory.new name: "#{cat['name']} #{test_id}",
                             desc: cat['desc'],
                             column_num: cat['column_num'],
                             units_reqts: (cat['unit_reqts']&.map do |r|
                               @unit_reqts.find { |u| u.name == "#{r['reqt']} #{test_id}" }
                             end),
                             course_reqs: (cat['courses']&.map do |course|
                               DegreeReqtCourse.new name: "#{course['name']} #{test_id}",
                                                    column_num: cat['column_num'],
                                                    transfer_course: course['transfer_course'],
                                                    units: course['units'],
                                                    units_reqts: (course['units_reqts']&.map do |r|
                                                      @unit_reqts.find { |u| u.name == "#{r['reqt']} #{test_id}" }
                                                    end)
                             end),
                             sub_categories: (cat['sub_categories']&.map do |sub|
                               DegreeReqtCategory.new name: "#{sub['name']} #{test_id}",
                                                      desc: sub['desc'],
                                                      column_num: cat['column_num'],
                                                      units_reqts: (sub['unit_reqts']&.map do |r|
                                                        @unit_reqts.find { |u| u.name == "#{r['reqt']} #{test_id}" }
                                                      end),
                                                      course_reqs: (sub['courses']&.map do |sub_course|
                                                        DegreeReqtCourse.new name: "#{sub_course['name']} #{test_id}",
                                                                             column_num: cat['column_num'],
                                                                             transfer_course: sub_course['transfer_course'],
                                                                             units: sub_course['units'],
                                                                             units_reqts: (sub_course['units_reqts']&.map do |r|
                                                                               @unit_reqts.find { |u| u.name == "#{r['reqt']} #{test_id}" }
                                                                             end)
                                                      end)
                             end)
    end

    if @categories
      @categories.each do |cat|
        if cat.course_reqs
          cat.course_reqs.each do |course|
            course.parent = cat
            course.units_reqts ||= []
            course.units_reqts += cat.units_reqts if cat.units_reqts&.any?
            course.units_reqts.uniq!
          end
        end
        if cat.sub_categories
          cat.sub_categories.each do |sub_cat|
            sub_cat.parent = cat
            sub_cat.units_reqts ||= []
            sub_cat.units_reqts += cat.units_reqts if cat.units_reqts&.any?
            sub_cat.units_reqts.uniq!
            if sub_cat.course_reqs
              sub_cat.course_reqs.each do |course|
                course.parent = sub_cat
                course.units_reqts ||= []
                course.units_reqts += sub_cat.units_reqts if sub_cat.units_reqts&.any?
                course.units_reqts.uniq!
              end
            end
          end
        end
      end
    end
  end

end
