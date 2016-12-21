require_relative '../../util/spec_helper'

describe 'My Dashboard My Classes card' do

  include Logging

  begin

    @driver = Utils.launch_browser

    user_test_data = Utils.load_test_users.select { |user| user['tests']['canvasMyClasses'] }
    testable_students = []
    testable_teachers = []

    test_output_heading = ['UID', 'Site Type', 'Site Name']
    test_output = Utils.initialize_canvas_test_output(self, test_output_heading)

    @academics_api = ApiMyAcademicsPage.new @driver
    @classes_api = ApiMyClassesPage.new @driver

    @splash_page = Page::CalCentralPages::SplashPage.new @driver
    @my_classes = Page::CalCentralPages::MyDashboardMyClassesCard.new @driver
    @class_sites_card = Page::CalCentralPages::MyAcademicsClassSitesCard.new @driver

    user_test_data.each do |user|
      uid = user['uid'].to_s
      logger.info("UID is #{uid}")

      begin
        @splash_page.load_page
        @splash_page.basic_auth uid
        @academics_api.get_feed @driver
        term = @classes_api.current_term @driver
        @my_classes.load_page

        # Student bCourses sites on My Classes

        @my_classes.enrolled_classes_div_element.when_present Utils.short_wait
        current_student_semester = @academics_api.current_semester @academics_api.all_student_semesters
        unless current_student_semester.nil?

          @my_classes.enrolled_classes_div_element.when_visible Utils.short_wait
          student_classes = @academics_api.semester_courses current_student_semester

          api_student_semester_site_names = @academics_api.semester_course_site_names student_classes
          api_student_semester_site_desc = @academics_api.semester_course_site_descrips student_classes

          ui_student_semester_site_names = @my_classes.enrolled_course_site_names
          ui_student_semester_site_desc = @my_classes.enrolled_course_site_descrips

          testable_students << uid if api_student_semester_site_names.any?

          it("shows the enrolled course site names for UID #{uid}") { expect(ui_student_semester_site_names).to eql(api_student_semester_site_names) }
          it("shows the enrolled course site descriptions for UID #{uid}") { expect(ui_student_semester_site_desc).to eql(api_student_semester_site_desc) }

          api_student_semester_site_names.each do |site|
            i = api_student_semester_site_names.index site
            row = [uid, 'student', api_student_semester_site_names[i]]
            Utils.add_csv_row(test_output, row)
          end

          # Student bCourses sites on class pages

          student_classes.each do |course|

            if @academics_api.multiple_primaries? course
              @academics_api.course_primary_sections(course).each do |prim_section|

                site_ids = @academics_api.section_side_ids prim_section
                section_sites = @academics_api.course_sites(course).select { |site| site_ids.include? @academics_api.course_site_id(site) }

                if section_sites.any?
                  testable_students << uid

                  api_site_names = section_sites.map { |site| @academics_api.course_site_name site }
                  api_site_urls = section_sites.map { |site| @academics_api.course_site_url site }

                  @my_classes.click_class_link_by_url @academics_api.section_url(prim_section)
                  @class_sites_card.class_sites_heading_element.when_visible Utils.medium_wait

                  ui_student_section_site_names = @class_sites_card.class_site_names
                  ui_student_section_site_urls = @class_sites_card.class_site_urls

                  it("shows the student class site names for UID #{uid} on the class page Class Sites card") { expect(ui_student_section_site_names).to eql(api_site_names) }
                  it("shows the student class site links for UID #{uid} on the class page Class Sites card") { expect(ui_student_section_site_urls).to eql(api_site_urls) }

                  @my_classes.load_page

                end
              end
            else

              course_sites = @academics_api.course_sites course

              unless course_sites.nil?
                testable_students << uid

                api_site_names = course_sites.map { |site| @academics_api.course_site_name site }
                api_site_urls = course_sites.map { |site| @academics_api.course_site_url site }

                @my_classes.click_class_link_by_url @academics_api.course_url(course)
                @class_sites_card.class_sites_heading_element.when_visible Utils.medium_wait

                ui_student_course_site_names = @class_sites_card.class_site_names
                ui_student_course_site_urls = @class_sites_card.class_site_urls

                it("shows the student class site names for UID #{uid} on the class page Class Sites card") { expect(ui_student_course_site_names).to eql(api_site_names) }
                it("shows the student class site links for UID #{uid} on the class page Class Sites card") { expect(ui_student_course_site_urls).to eql(api_site_urls) }

                @my_classes.load_page

              end
            end
          end
        end

        # Teaching bCourses sites on My Classes

        current_teaching_semester = @academics_api.current_semester @academics_api.all_teaching_semesters
        unless current_teaching_semester.nil?

          @my_classes.teaching_classes_div_element.when_visible Utils.short_wait
          teaching_classes = @academics_api.semester_courses current_teaching_semester

          api_teach_semester_site_names = @academics_api.semester_course_site_names teaching_classes
          api_teach_semester_site_desc = @academics_api.semester_course_site_descrips teaching_classes

          ui_teach_semester_site_names = @my_classes.teaching_course_site_names
          ui_teach_semester_site_desc = @my_classes.teaching_course_site_descrips

          testable_teachers << uid if api_teach_semester_site_names.any?

          it("shows the teaching course site names for UID #{uid}") { expect(ui_teach_semester_site_names).to eql(api_teach_semester_site_names) }
          it("shows the teaching course site descriptions for UID #{uid}") { expect(ui_teach_semester_site_desc).to eql(api_teach_semester_site_desc) }

          api_teach_semester_site_names.each do |site|
            i = api_teach_semester_site_names.index site
            row = [uid, 'teaching', api_teach_semester_site_names[i]]
            Utils.add_csv_row(test_output, row)
          end

          # Teaching bCourses sites on class pages

          teaching_classes.each do |course|

            course_sites = @academics_api.course_sites course

            unless course_sites.nil?
              testable_teachers << uid

              api_site_names = course_sites.map { |site| @academics_api.course_site_name site }
              api_site_urls = course_sites.map { |site| @academics_api.course_site_url site }

              @my_classes.click_class_link_by_url @academics_api.course_url(course)
              @class_sites_card.class_sites_heading_element.when_visible Utils.medium_wait

              ui_teach_course_site_names = @class_sites_card.class_site_names
              ui_teach_course_site_urls = @class_sites_card.class_site_urls

              it("shows the teaching class site names for UID #{uid} on the class page Class Sites card") { expect(ui_teach_course_site_names).to eql(api_site_names) }
              it("shows the teaching class site links for UID #{uid} on the class page Class Sites card") { expect(ui_teach_course_site_urls).to eql(api_site_urls) }

              @my_classes.load_page

            end
          end
        end

        # Other Sites

        other_sites = @academics_api.other_sites term

        if other_sites.any?

          @my_classes.other_sites_div_element.when_visible Utils.short_wait

          api_other_site_names = @academics_api.other_site_names other_sites
          api_other_site_desc = @academics_api.other_site_descriptions other_sites

          ui_other_site_names = @my_classes.other_course_site_names
          ui_other_site_desc = @my_classes.other_course_site_descrips

          it("shows the 'other' course site names for UID #{uid}") { expect(ui_other_site_names).to eql(api_other_site_names) }
          it("shows the 'other' course site descriptions for UID #{uid}") { expect(ui_other_site_desc).to eql(api_other_site_desc) }

          api_other_site_names.each do |site|
            i = api_other_site_names.index site
            row = [uid, 'other', api_other_site_names[i]]
            Utils.add_csv_row(test_output, row)
          end

        end

      rescue => e
        it("encountered an error with UID #{uid}") { fail }
        logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
      end
    end
  rescue => e
    it('encountered an error') { fail }
    logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
  ensure
    Utils.quit_browser @driver
  end
end
