require_relative '../../util/spec_helper'

module Page

  module BOACPages

    module CohortPages

      class FilteredCohortListViewPage < FilteredCohortPage

        include Logging
        include PageObject
        include Page
        include BOACPages
        include CohortPages

        # Returns the sequence of SIDs that should be present when search results are sorted by first name
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortSearchCriteria]
        # @return [Array<String>]
        def expected_sids_by_first_name(user_data, search_criteria)
          expected_users = expected_search_results(user_data, search_criteria)
          sorted_users = expected_users.sort_by { |u| [u[:first_name].downcase, u[:last_name].downcase, u[:sid]] }
          sorted_users.map { |u| u[:sid] }
        end

        # Returns the sequence of SIDs that should be present when search results are sorted by last name
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortSearchCriteria]
        # @return [Array<String>]
        def expected_sids_by_last_name(user_data, search_criteria)
          expected_users = expected_search_results(user_data, search_criteria)
          sorted_users = expected_users.sort_by { |u| [u[:last_name].downcase, u[:first_name].downcase, u[:sid]] }
          sorted_users.map { |u| u[:sid] }
        end

        # Returns the sequence of SIDs that should be present when search results are sorted by team
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortSearchCriteria]
        # @return [Array<String>]
        def expected_sids_by_team(user_data, search_criteria)
          expected_users = expected_search_results(user_data, search_criteria)
          sorted_users = expected_users.sort_by { |u| [u[:squad_names].sort.first, u[:last_name].downcase, u[:first_name].downcase] }
          sorted_users.map { |u| u[:sid] }
        end

        # Returns the sequence of SIDs that should be present when search results are sorted by GPA
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortSearchCriteria]
        # @return [Array<String>]
        def expected_sids_by_gpa(user_data, search_criteria)
          expected_users = expected_search_results(user_data, search_criteria)
          sorted_users = expected_users.sort_by { |u| [u[:gpa].to_f, u[:last_name].downcase, u[:first_name].downcase] }
          sorted_users.map { |u| u[:sid] }
        end

        # Returns the sequence of SIDs that should be present when search results are sorted by level
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortSearchCriteria]
        # @return [Array<String>]
        def expected_sids_by_level(user_data, search_criteria)
          expected_users = expected_search_results(user_data, search_criteria)
          # Sort first by the secondary sort order
          users_by_first_name = expected_users.sort_by { |u| [u[:last_name].downcase, u[:first_name].downcase] }
          # Then arrange by the sort order for level
          users_by_level = []
          %w(Freshman Sophomore Junior Senior Graduate).each do |level|
            users_by_level << users_by_first_name.select do |u|
              u[:level] == level
            end
          end
          users_by_level.flatten.map { |u| u[:sid] }
        end

        # Returns the sequence of SIDs that should be present when search results are sorted by major
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortSearchCriteria]
        # @return [Array<String>]
        def expected_sids_by_major(user_data, search_criteria)
          expected_users = expected_search_results(user_data, search_criteria)
          sorted_users = expected_users.sort_by { |u| [u[:majors].sort.first, u[:last_name].downcase, u[:first_name].downcase] }
          sorted_users.map { |u| u[:sid] }
        end

        # Returns the sequence of SIDs that should be present when search results are sorted by cumulative units
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortSearchCriteria]
        # @return [Array<String>]
        def expected_sids_by_units(user_data, search_criteria)
          expected_users = expected_search_results(user_data, search_criteria)
          sorted_users = expected_users.sort_by { |u| [u[:units].to_f, u[:last_name].downcase, u[:first_name].downcase] }
          sorted_users.map { |u| u[:sid] }
        end

      end
    end
  end
end
