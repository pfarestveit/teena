require_relative '../../util/spec_helper'

module Page
  module BOACPages
    module UserListPages

      class HomePage

        include PageObject
        include Logging
        include Page
        include BOACPages
        include UserListPages

        button(:sign_in, id: 'splash-sign-in')
        div(:sign_in_msg, xpath: '//div[text()="Please sign in."]')

        text_field(:dev_auth_uid_input, id: 'dev-auth-uid')
        text_field(:dev_auth_password_input, id: 'dev-auth-password')
        button(:dev_auth_log_in_button, id: 'dev-auth-submit')

        # Loads the home page
        def load_page
          navigate_to BOACUtils.base_url
          wait_for_spinner
        end

        # Logs in via CAS
        # @param username [String]
        # @param password [String]
        # @param cal_net [Page::CalNetPage]
        def log_in(username, password, cal_net)
          load_page
          wait_for_title 'Welcome'
          wait_for_load_and_click sign_in_element
          cal_net.log_in(username, password)
          wait_for_title 'Home'
        end

        # Authenticates using dev auth
        # @param user [User]
        def dev_auth(user = nil)
          logger.info "Logging in #{('UID ' + user.uid.to_s + ' ') if user}using developer auth"
          start = Time.now
          load_page
          scroll_to_bottom
          wait_for_element_and_type(dev_auth_uid_input_element, (user ? user.uid : Utils.super_admin_uid))
          logger.warn "Took #{Time.now - start - Utils.click_wait} seconds for dev auth input to become available"
          wait_for_element_and_type(dev_auth_password_input_element, BOACUtils.password)
          wait_for_update_and_click dev_auth_log_in_button_element
          wait_for_title 'Home'
        end

        # GENERIC USER DATA UI

        # Returns all the user divs beneath a cohort or group designated by its XPath
        # @param driver [Selenium::WebDriver]
        # @param xpath [String]
        # @return [Array<Selenium::WebDriver::Element>]
        def user_rows(driver, xpath)
          driver.find_elements(xpath: "#{xpath}//tr[contains(@data-ng-repeat,'student in students')]")
        end

        # FILTERED COHORTS AND CURATED GROUPS

        elements(:filtered_cohort, :span, xpath: '//div[@data-ng-repeat="cohort in profile.myFilteredCohorts track by $index"]//h2/span[@data-ng-bind="cohort.name"]')
        h1(:no_filtered_cohorts_msg, xpath: '//h1[contains(.,"You have no saved cohorts.")]')
        elements(:curated_group, :span, xpath: '//div[@data-ng-repeat="cohort in profile.myCuratedCohorts track by $index"]//h2/span[@data-ng-bind="cohort.name"]')

        # Returns the names of filtered cohorts shown on the homepage
        # @return [Array<String>]
        def filtered_cohorts
          h1_element(xpath: '//h1[contains(text(),"Cohorts")]').when_present Utils.medium_wait
          wait_until(Utils.medium_wait) { filtered_cohort_elements.any? }
          filtered_cohort_elements.map &:text
        end

        # Returns the XPath to a filtered cohort's div in the main content area on the homepage
        # @param cohort [FilteredCohort]
        # @return [String]
        def filtered_cohort_xpath(cohort)
          "//div[@id=\"content\"]//div[@data-ng-repeat=\"cohort in profile.myFilteredCohorts track by $index\"][contains(.,\"#{cohort.name}\")]"
        end

        # Returns the names of curated groups shown on the homepage
        # @return [Array<String>]
        def curated_groups
          h1_element(xpath: '//h1[contains(text(),"Curated Groups")]').when_present Utils.medium_wait
          wait_until(Utils.medium_wait) { curated_group_elements.any? }
          curated_group_elements.map &:text
        end

        # Returns the XPath to a curated group's div in the main content area on the homepage
        # @param group [CuratedGroup]
        # @return [String]
        def curated_group_xpath(group)
          "//div[@id=\"content\"]//div[@data-ng-repeat=\"cohort in profile.myCuratedCohorts track by $index\"][contains(.,\"#{group.name}\")]"
        end

        # Returns the link to a filtered cohort or curated group in the main content area of the homepage
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Link]
        def view_all_members_link(cohort)
          cohort.instance_of?(FilteredCohort) ?
              link_element(xpath: "#{filtered_cohort_xpath cohort}//a[contains(@href,'/filtered?id=#{cohort.id}')]") :
              link_element(xpath: "#{curated_group_xpath cohort}//a[contains(@href,'/curated/#{cohort.id}')]")
        end

        # Expands a filtered cohort or curated group row in the main content area
        # @param cohort [Cohort]
        def expand_member_rows(cohort)
          unless view_all_members_link(cohort).visible?
            cohort.instance_of?(FilteredCohort) ?
                wait_for_update_and_click(link_element(xpath: "#{filtered_cohort_xpath cohort}//a")) :
                wait_for_update_and_click(link_element(xpath: "#{curated_group_xpath cohort}//a"))
          end
        end

        # Returns all the user divs beneath a filtered cohort or curated group
        # @param driver [Selenium::WebDriver]
        # @param cohort [Cohort]
        # @return [Array<Selenium::WebDriver::Element>]
        def member_rows(driver, cohort)
          cohort.instance_of?(FilteredCohort) ?
            user_rows(driver, filtered_cohort_xpath(cohort)) :
            user_rows(driver, curated_group_xpath(cohort))
        end

        # Returns the membership count shown for a filtered cohort or curated group
        # @param cohort [Cohort]
        # @return [Integer]
        def member_count(cohort)
          xpath = cohort.instance_of?(FilteredCohort) ?
              "#{filtered_cohort_xpath(cohort)}//span[@data-ng-bind=\"cohort.totalStudentCount\"]" :
              "#{curated_group_xpath(cohort)}//span[@data-ng-bind=\"cohort.studentCount\"]"
          el = span_element(xpath: xpath)
          el.text.to_i if el.exists?
        end

        # Verifies the user + alert data shown for a filtered cohort's or curated group's membership
        # @param driver [Selenium::WebDriver]
        # @param cohort [Cohort]
        # @param advisor [User]
        def verify_member_alerts(driver, cohort, advisor)

          # Only cohort members with alerts should be shown. Collect the expected alert count for each member, and toss out those with a zero count.
          member_alerts = cohort.members.any? ? BOACUtils.get_un_dismissed_users_alerts(cohort.members, advisor) : []
          cohort.member_data.keep_if do |member|
            alert_count = member_alerts.count { |a| a.user.sis_id == member[:sid] }
            logger.debug "SID #{member[:sid]} has alert count #{alert_count}" unless alert_count.zero?
            member.merge!(:alert_count => alert_count)
            member[:alert_count].to_i > 0
          end

          # Expand the cohort, and verify that there are only rows for members with alerts
          view_all_members_link(cohort).when_visible Utils.short_wait
          wait_until(1, "Expecting cohort #{cohort.name} to have row count of #{cohort.member_data.length}, got #{member_rows(driver, cohort).length}") do
            member_rows(driver, cohort).length == cohort.member_data.length
          end

          # Verify that there is a row for each student with a positive alert count and that the alert count is right
          xpath = cohort.instance_of?(FilteredCohort) ? filtered_cohort_xpath(cohort) : curated_group_xpath(cohort)
          cohort.member_data.each do |member|
            logger.debug "Checking cohort row for SID #{member[:sid]}"
            wait_until(1, "Expecting SID #{member[:sid]} alert count #{member[:alert_count]}, got #{user_row_data(driver, member[:sid], xpath)[:alert_count]}") do
              user_row_data(driver, member[:sid], xpath)[:alert_count] == member[:alert_count].to_s
            end
          end
        end

        # Clicks the link for a given Filtered Cohort
        # @param cohort [FilteredCohort]
        def click_filtered_cohort(cohort)
          logger.debug "Clicking link to my cohort '#{cohort.name}'"
          wait_until(Utils.short_wait) { filtered_cohort_elements.any? }
          wait_for_update_and_click_js view_all_members_link(cohort)
        end

      end
    end
  end
end
