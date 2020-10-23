require_relative '../../util/spec_helper'

module BOACUserListPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  # Returns all the SIDs visible in a list. If a cohort is given, then returns the SIDs shown under that cohort.
  # @param cohort [Cohort]
  def all_row_sids(cohort = nil)
    # TODO - account for curated cohorts too
    xpath = filtered_cohort_xpath cohort if cohort && cohort.instance_of?(FilteredCohort)
    span_elements(xpath: "#{xpath}//span[text()=\"S I D\"]/following-sibling::span").map &:text
  end

  # Returns the XPath to a filtered cohort's div in the main content area on the homepage
  # @param cohort [FilteredCohort]
  # @return [String]
  def filtered_cohort_xpath(cohort)
    "//div[@id=\"sortable-cohort-#{cohort.id}\"]"
  end

  # Returns the data visible for a user on the search results page or in a filtered or curated cohort on the homepage. If an XPath is included,
  # then returns rows under the associated filtered cohort or curated group.
  # @param sid [String]
  # @param cohort_xpath [String]
  # @return [Hash]
  def user_row_data(sid, cohort_xpath = nil)
    row_xpath = "#{cohort_xpath}//tr[contains(.,\"#{sid}\")]"
    name_el = link_element(xpath: "#{row_xpath}//span[text()=\"Student name\"]/following-sibling::a")
    sid_el = span_element(xpath: "#{row_xpath}//span[text()=\"S I D\"]/following-sibling::span")
    major_els = div_elements(xpath: "#{row_xpath}//span[text()=\"Major\"]/following-sibling::div")
    term_units_el = div_element(xpath: "#{row_xpath}//span[text()=\"Term units\"]/following-sibling::div")
    cumul_units_el = div_element(xpath: "#{row_xpath}//span[text()=\"Units completed\"]/following-sibling::div")
    no_cumul_units_el = span_element(xpath: "#{row_xpath}//span[text()=\"Units completed\"]/following-sibling::div/span")
    gpa_el = div_element(xpath: "#{row_xpath}//span[text()=\"GPA\"]/following-sibling::div")
    no_gpa_el = span_element(xpath: "#{row_xpath}//span[text()=\"GPA\"]/following-sibling::div/span")
    alerts_el = div_element(xpath: "#{row_xpath}//span[text()=\"Issue count\"]/following-sibling::div")
    units = if cumul_units_el.exists?
              cumul_units_el.text
            elsif no_cumul_units_el.exists?
              no_cumul_units_el.text
            end
    gpa = if gpa_el.exists?
            gpa_el.text
          elsif no_gpa_el.exists?
            no_gpa_el.text
          end
    {
        :name => (name_el.text if name_el.exists?),
        :sid => (sid_el.text if sid_el.exists?),
        :major => major_els.map(&:text),
        :term_units => (term_units_el.text if term_units_el.exists?),
        :cumulative_units => units,
        :gpa => gpa,
        :alert_count => (alerts_el.text if alerts_el.exists?)
    }
  end

  # Sorts a user list by name
  # @param cohort [Cohort]
  def sort_by_name(cohort = nil)
    sort_by_option('Name', cohort)
  end

  # Sorts a user list by SID
  # @param cohort [Cohort]
  def sort_by_sid(cohort = nil)
    sort_by_option('SID', cohort)
  end

  # Sorts a user list by major
  # @param cohort [Cohort]
  def sort_by_major(cohort = nil)
    sort_by_option('Major', cohort)
  end

  # Sorts a user list by expected graduation term
  # @param cohort [Cohort]
  def sort_by_expected_grad(cohort = nil)
    sort_by_option('Grad', cohort)
  end

  # Sorts a user list by term units
  # @param cohort [Cohort]
  def sort_by_term_units(cohort = nil)
    sort_by_option('Term units', cohort)
  end

  # Sorts a user list by cumulative units
  # @param cohort [Cohort]
  def sort_by_cumul_units(cohort = nil)
    sort_by_option('Units completed', cohort)
  end

  # Sorts a user list by GPA
  # @param cohort [Cohort]
  def sort_by_gpa(cohort = nil)
    sort_by_option('GPA', cohort)
  end

  # Sorts a user list by alert count
  # @param cohort [Cohort]
  def sort_by_alert_count(cohort = nil)
    sort_by_option('Alerts', cohort)
  end

  # Returns the sequence of SIDs that should be present when sorted by alert count ascending
  # @param users [Array<BOACUser>]
  # @return [Array<String>]
  def expected_sids_by_alerts(users)
    sorted_users = users.sort_by { |u| [u.alert_count, u.last_name.downcase, u.first_name.downcase, u.sis_id] }
    sorted_users.map { |u| u.sis_id }
  end

  # Returns the sequence of SIDs that should be present when sorted by alert count descending
  # @param users [Array<BOACUser>]
  # @return [Array<String>]
  def expected_sids_by_alerts_desc(users)
    sorted_users = users.sort do |a, b|
      [b.alert_count, a.last_name.downcase, a.first_name.downcase, a.sis_id] <=>
          [a.alert_count, b.last_name.downcase, b.first_name.downcase, b.sis_id]
    end
    sorted_users.map { |u| u.sis_id }
  end

end
