require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class SplashPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      button(:sign_in, id: 'sign-in-button')

      # Loads the Junction splash page
      def load_page
        navigate_to JunctionUtils.junction_base_url
      end

      # Authenticates using basic auth
      # @param uid [String]
      # @param cal_net [Page::CalNetPage]
      def basic_auth(uid, cal_net = nil)
        logger.info "Logging in as #{uid} using basic auth"
        load_page
        build_summary_heading_element.when_visible Utils.medium_wait
        scroll_to_bottom
        begin
          log_out if log_out_link?
        rescue
          logger.warn 'Session conflict, CAS page loaded'
          cal_net.log_out
          navigate_to "#{JunctionUtils.junction_base_url}/logout"
          wait_until(Utils.short_wait) { text.include? 'redirectUrl' }
          load_page
          scroll_to_bottom
        end
        wait_for_element_and_type_js(basic_auth_uid_input_element, uid)
        wait_for_element_and_type_js(basic_auth_password_input_element, JunctionUtils.junction_basic_auth_password)
        # The log in button element will disappear and reappear
        button = basic_auth_log_in_button_element
        button.click
        button.when_not_present timeout=Utils.medium_wait
        sleep 1
      end

      # Clicks the sign in button on the splash page
      def click_sign_in_button
        wait_for_load_and_click sign_in_element
      end

      def resolve_lti_session_conflict(cal_net_page)
        load_page
        logger.warn 'Resolving any LTI session conflicts'
        wait_until(Utils.short_wait) do
          basic_auth_uid_input? || cal_net_page.username? || log_out_link?
          if cal_net_page.username?
            logger.debug 'CAS login page loaded, entering credentials'
            cal_net_page.enter_credentials(Utils.super_admin_username, Utils.super_admin_password)
            wait_until(Utils.short_wait) do
              cal_net_page.logout_conf_heading? || log_out_link?
              if log_out_link?
                logger.debug 'Logged in to Junction, logging out'
                log_out
              else
                logger.debug 'Logged out of CAS'
              end
            end
          elsif log_out_link?
            logger.debug 'Junction page loaded, logging out'
            log_out
          else
            logger.debug 'Basic auth is already present'
          end
        end
      end

    end
  end
end
