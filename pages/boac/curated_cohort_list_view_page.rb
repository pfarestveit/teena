require_relative '../../util/spec_helper'

module Page

  module BOACPages

    module CohortPages

      class CuratedCohortListViewPage < CuratedCohortPage

        include PageObject
        include Logging
        include Page
        include BOACPages
        include CohortPages

        # Removes a student from a curated cohort
        # @param driver [Selenium::WebDriver]
        # @param student [User]
        # @param cohort [CuratedCohort]
        def curated_remove_student(driver, student, cohort)
          logger.info "Removing UID #{student.uid} from cohort '#{cohort.name}'"
          wait_for_student_list
          student_link = link_element(:id => student.uid)
          wait_for_update_and_click image_element(:id => "student-#{student.uid}-curated-cohort-remove")
          student_link.when_not_present Utils.medium_wait
          cohort.members.delete student
          wait_for_sidebar_curated_member_count cohort
        end

      end
    end
  end
end
