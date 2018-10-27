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
          driver.find_elements(xpath: "#{xpath}//div[contains(@data-ng-repeat,'student in students')]")
        end

        # CURATED COHORTS

        link(:home_create_first_curated_link, id: 'home-curated-cohort-create')
        link(:home_create_curated_link, id: 'home-curated-cohorts-create-link')
        link(:home_manage_curated_link, id: 'home-curated-cohorts-manage-link')
        div(:home_no_curated_cohorts_msg, xpath: '//h1[text()="Curated Cohorts"]/../following-sibling::div[contains(.,"You have no curated cohorts.")]')

        # Creates a curated cohort using the 'Create' link in the main content area of the homepage
        # @param cohort [CuratedCohort]
        def home_create_curated(cohort)
          wait_for_load_and_click home_create_curated_link_element
          name_and_save_curated_cohort cohort
          wait_for_sidebar_curated cohort
        end

        # Creates a curated cohort using the 'Create a new curated cohort' link shown on the homepage when no other curated cohorts exist
        # @param cohort [CuratedCohort]
        def home_create_first_curated(cohort)
          wait_for_load_and_click home_create_first_curated_link_element
          name_and_save_curated_cohort cohort
          wait_for_sidebar_curated cohort
        end

        # Clicks the manage-curate link in the main content area
        def click_home_manage_curated
          wait_for_load_and_click home_manage_curated_link_element
          wait_for_title 'Manage Curated Cohorts'
        end

        # Returns the element for a user on My List
        # @param user [User]
        # @return [PageObject::Elements::Row]
        def curated_cohort_user_row(user)
          row_element(xpath: "//h2[text()='Curated Cohorts']/following-sibling::div//tr[contains(.,\"#{user.last_name}, #{user.first_name}\")][contains(.,\"#{user.sis_id}\")]")
        end

        # Checks if a user is marked inactive in My List
        # @param user [User]
        # @return [boolean]
        def curated_cohort_user_inactive?(user)
          curated_cohort_user_row(user).span_element(class: 'home-inactive-info-icon').exists?
        end

        # Removes a user from My List
        # @param user [User]
        def remove_curated_cohort_member(user)
          wait_for_load_and_click watchlist_toggle(user)
          curated_cohort_user_row(user).when_not_present Utils.short_wait
        end

        # Removes all users from My List
        def remove_all_from_watchlist
          load_page
          if my_list_remove_button_elements.any?
            logger.info "Removing #{my_list_remove_button_elements.length} users from My List"
            my_list_remove_button_elements.each do |el|
              el.click
              el.when_not_present Utils.short_wait
            end
          else
            logger.info 'There are no users on My List'
          end
        end

        # FILTERED COHORTS

        elements(:filtered_cohort, :span, xpath: '//div[@data-ng-repeat="cohort in myFilteredCohorts"]//h2/span[1]')
        link(:home_create_filtered_link, id: 'create-another-filtered-cohort')
        div(:no_filtered_cohorts_msg, xpath: '//div[contains(.,"You have no filtered cohorts.")]')

        # Returns the names of My Saved Cohorts shown on the homepage
        # @return [Array<String>]
        def filtered_cohorts
          h1_element(xpath: '//h1[text()="Filtered Cohorts"]').when_present Utils.medium_wait
          wait_until(Utils.medium_wait) { filtered_cohort_elements.any? }
          filtered_cohort_elements.map &:text
        end

        # Returns the 'view all' link on a filtered cohort row
        # @param cohort [FilteredCohort]
        # @return [PageObject::Elements::Link]
        def filtered_cohort_view_all_link(cohort)
          link_element(xpath: "//h1[text()='Filtered Cohorts']/../following-sibling::*//a[contains(@href,'/filtered?id=#{cohort.id}')]")
        end

        # Expands a filtered cohort row in the main content area
        # @param cohort [FilteredCohort]
        def expand_filtered_cohort(cohort)
          wait_for_update_and_click link_element(xpath: "#{filtered_cohort_xpath cohort}//a") unless filtered_cohort_view_all_link(cohort).visible?
        end

        # Returns all the user divs beneath a cohort
        # @param driver [Selenium::WebDriver]
        # @param cohort [FilteredCohort]
        # @return [Array<Selenium::WebDriver::Element>]
        def filtered_cohort_member_rows(driver, cohort)
          user_rows(driver, filtered_cohort_xpath(cohort))
        end

        # Returns the membership count shown for a cohort
        # @param cohort [FilteredCohort]
        # @return [Integer]
        def filtered_cohort_member_count(cohort)
          el = span_element(xpath: "#{filtered_cohort_xpath cohort}//span[@data-ng-bind=\"cohort.totalStudentCount\"]")
          el && el.text.to_i
        end

        def visible_filtered_cohort_members(driver, cohort, searchable_students)
          expand_filtered_cohort cohort
          visible_sids = all_row_sids(driver, cohort)
          searchable_students.select { |s| visible_sids.include? s[:sid] }
        end

        # Verifies the user + alert data shown for a cohort's membership
        # @param driver [Selenium::WebDriver]
        # @param cohort [FilteredCohort]
        # @param members [Array<User>]
        # @param advisor [User]
        def verify_filtered_cohort_alerts(driver, cohort, members, advisor)

          # Only cohort members with alerts should be shown. Collect the expected alert count for each member, and toss out those with a zero count.
          member_alerts = members.any? ? BOACUtils.get_un_dismissed_users_alerts(members, advisor) : []
          cohort.member_data.keep_if do |member|
            alert_count = member_alerts.count { |a| a.user.sis_id == member[:sid] }
            logger.debug "SID #{member[:sid]} has alert count #{alert_count}" unless alert_count.zero?
            member.merge!(:alert_count => alert_count)
            member[:alert_count].to_i > 0
          end

          # Expand the cohort, and verify that there are only rows for members with alerts
          wait_until(1, "Expecting cohort #{cohort.name} to have row count of #{cohort.member_data.length}, got #{filtered_cohort_member_rows(driver, cohort).length}") do
            filtered_cohort_member_rows(driver, cohort).length == cohort.member_data.length
          end

          # Verify that there is a row for each student with a positive alert count and that the alert count is right
          cohort.member_data.each do |member|
            logger.debug "Checking cohort row for SID #{member[:sid]}"
            wait_until(1, "Expecting alert count #{member[:alert_count]}, got #{user_row_data(driver, member, cohort)[:alert_count]}") do
              user_row_data(driver, member, cohort)[:alert_count] == member[:alert_count].to_s
            end
          end
        end

        # Clicks the link for a given Filtered Cohort
        # @param cohort [FilteredCohort]
        def click_filtered_cohort(cohort)
          logger.debug "Clicking link to my cohort '#{cohort.name}'"
          wait_until(Utils.short_wait) { filtered_cohort_elements.any? }
          wait_for_update_and_click_js filtered_cohort_view_all_link(cohort)
        end

      end
    end
  end
end
