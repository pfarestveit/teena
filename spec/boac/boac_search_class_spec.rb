require_relative '../../util/spec_helper'

unless ENV['DEPS']

  describe 'BOAC' do

    include Logging

    begin

      test_config = BOACTestConfig.new
      test_config.search_classes

      @driver = Utils.launch_browser test_config.chrome_profile
      @homepage = BOACHomePage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @student_page = BOACStudentPage.new @driver
      @class_page = BOACClassListViewPage.new @driver
      @homepage.dev_auth test_config.advisor

      test_config.test_students.each do |student|

        begin
          api_student_page = BOACApiStudentPage.new @driver
          api_student_page.get_data(@driver, student)
          term = api_student_page.terms.find { |t| api_student_page.term_name(t) == BOACUtils.term }

          if term
            term_id = api_student_page.term_id term
            courses = api_student_page.courses term
            courses.each do |course|

              begin
                course_sis_data = api_student_page.sis_course_data course
                unless course_sis_data[:code].include? 'PHYS ED' # PHYS ED has too many identical-looking sections

                  api_student_page.sections(course).each do |section|
                    section_data = api_student_page.sis_section_data section
                    if section_data[:primary]

                      begin
                        api_section_page = BOACApiSectionPage.new @driver
                        api_section_page.get_data(term_id, section_data[:ccn])

                        section_test_case = "course #{course_sis_data[:code]} section #{section_data[:component]} #{section_data[:number]} #{section_data[:ccn]}"
                        course_code = api_section_page.course_code
                        subject_area, separator, catalog_id = course_code.rpartition(' ')
                        abbreviated_subject_area = subject_area[0..-3]
                        strings = [course_code, "#{abbreviated_subject_area} #{catalog_id}"]
                        strings << catalog_id if catalog_id.length > 1

                        @homepage.load_page
                        strings.each do |string|
                          begin

                            @homepage.type_non_note_simple_search_and_enter string
                            class_result = @search_results_page.class_in_search_result?(course_code, section_data[:number])
                            if @search_results_page.partial_results_msg?
                              logger.warn "Skipping search for '#{string}' because there are more than 50 results"
                            else
                              it("allows the user to search for #{section_test_case} by string '#{string}'") { expect(class_result).to be true }
                            end

                            if @search_results_page.class_link(course_code, section_data[:number]).exists? && string == strings.first
                              @search_results_page.click_class_result(course_code, section_data[:number])
                              class_link_works = @class_page.verify_block { @class_page.wait_for_title course_code }
                              it("allows the user to visit the class page for #{section_test_case} from search results") { expect(class_link_works).to be true }
                            end

                          rescue => e
                            Utils.log_error e
                            it("hit an error with a search for #{section_test_case} by string '#{string}'") { fail e.message }
                          end
                        end

                      rescue => e
                        Utils.log_error e
                        it("hit an error performing a class search for #{section_test_case}") { fail e.message }
                      end
                    end
                  end
                end

              rescue => e
                Utils.log_error e
                it("hit an error with class search tests for UID #{student.uid} course #{course['displayName']}") { fail e.message }
              end
            end
          else
            logger.warn "Bummer, UID #{student.uid} has no classes in the current term to search for"
          end

        rescue => e
          Utils.log_error e
          it("hit an error with UID #{student.uid}") { fail e.message }
        end
      end
    end
  end
end
