require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class CohortPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      elements(:player_link, :link, class: 'cohort-member-list-item')
      elements(:player_name, :h3, class: 'cohort-member-name')
      elements(:player_uid, :div, class: 'cohort-member-uid')

      # Returns all the player names shown on the page
      # @return [Array<String>]
      def team_player_names
        wait_until(Utils.medium_wait) { player_link_elements.any? }
        player_name_elements.map &:text
      end

      # Returns all the player UIDs shown on the page
      # @return [Array<String>]
      def team_player_uids
        wait_until(Utils.medium_wait) { player_link_elements.any? }
        player_uid_elements.map &:text
      end

      # Clicks the link for a given player
      # @param player [User]
      def click_player_link(player)
        logger.info "Clicking the link for UID #{player.uid}"
        wait_for_load_and_click link_element(xpath: "//a[contains(.,\"#{player.full_name}\")]")
        h1_element(xpath: '//h1[@data-ng-bind="student.sisProfile.primaryName"]').when_visible Utils.medium_wait
      end

    end
  end
end
