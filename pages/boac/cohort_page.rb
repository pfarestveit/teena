require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class CohortPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      # TEAMS

      elements(:player_link, :link, class: 'cohort-member-list-item')
      elements(:player_name, :h3, class: 'cohort-member-name')
      elements(:player_sid, :div, class: 'cohort-member-sid')

      # Returns all the player names shown on the page
      # @return [Array<String>]
      def team_player_names
        wait_until(Utils.medium_wait) { player_link_elements.any? }
        player_name_elements.map &:text
      end

      # Returns all the player SIDs shown on the page
      # @return [Array<String>]
      def team_player_sids
        wait_until(Utils.medium_wait) { player_link_elements.any? }
        player_sid_elements.map &:text
      end

      # Clicks the link for a given player
      # @param player [User]
      def click_player_link(player)
        logger.info "Clicking the link for UID #{player.uid}"
        wait_for_load_and_click link_element(xpath: "//a[contains(.,\"#{player.sis_id}\")]")
        h1_element(xpath: '//h1[@data-ng-bind="student.sisProfile.primaryName"]').when_visible Utils.medium_wait
      end

      # CUSTOM COHORTS

      button(:teams_filter_button, id: 'search-filter-teams')
      button(:search_button, id: 'header-sign-in')
      button(:create_cohort_button, id: 'create-cohort-btn')

      # Returns the option for a given squad
      # @param squad [Squad]
      # @return [PageObject::Elements::Option]
      def squad_option_element(squad)
        text_area_element(id: "search-option-team-#{squad.code}")
      end

    end
  end
end
