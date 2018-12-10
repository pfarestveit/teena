require_relative '../../util/spec_helper'

class BOACTeamsListPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  # TEAMS

  elements(:team_cohort_link, :link, xpath: '//a[@data-ng-bind="team.name"]')

  # Loads the teams list page
  def load_page
    navigate_to "#{BOACUtils.base_url}/teams"
  end

  # Returns the text of all the team cohort links
  # @return [Array<String>]
  def teams
    wait_until(Utils.medium_wait) { team_cohort_link_elements.any? }
    team_cohort_link_elements.map &:text
  end

  # Clicks the dashboard link for a team
  # @param team [Team]
  def click_team_link(team)
    logger.info "Clicking link for #{team.name}"
    wait_for_load_and_click link_element(xpath: "//a[text()=\"#{team.name}\"]")
  end

end
