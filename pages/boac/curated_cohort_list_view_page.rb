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
        # @param student [User]
        # @param cohort [CuratedCohort]
        def curated_remove_student(student, cohort)
          logger.info "Removing UID #{student.uid} from cohort '#{cohort.name}'"
          wait_for_student_list
          wait_for_update_and_click button_element(:id => "student-#{student.uid}-curated-cohort-remove")
          cohort.members.delete student
          sleep 2
          wait_until(Utils.short_wait) { list_view_uids.sort == cohort.members.map(&:uid).sort }
          wait_for_sidebar_curated_member_count cohort
        end

      end
    end
  end
end
