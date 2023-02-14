require_relative '../../util/spec_helper'

class RipleySplashPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  def load_page
    navigate_to RipleyUtils.base_url
  end

  # Log in

  button(:sign_in, id: 'TBD')

  def click_sign_in_button
    wait_for_load_and_click sign_in_element
  end

  # Dev Auth

  text_field(:dev_auth_uid_input, id: 'basic-auth-uid')
  text_field(:dev_auth_password_input, id: 'basic-auth-password')
  button(:dev_auth_log_in_button, id: 'basic-auth-submit-button')

  def dev_auth(uid, cal_net = nil)
    logger.info "Logging in as #{uid} using dev auth"
    load_page
    begin
      log_out if log_out_link?
    rescue
      logger.warn 'Session conflict, CAS page loaded'
      cal_net.log_out
      navigate_to "#{RipleyUtils.base_url}/logout"
      wait_until(Utils.short_wait) { text.include? 'redirectUrl' }
      load_page
    end
    wait_for_element_and_type(dev_auth_uid_input_element, uid)
    wait_for_element_and_type(dev_auth_password_input_element, RipleyUtils.dev_auth_password)
    wait_for_update_and_click dev_auth_log_in_button_element
    sleep 1
  end

  def resolve_lti_session_conflict(cal_net_page)
    load_page
    logger.warn 'Resolving any LTI session conflicts'
    wait_until(Utils.long_wait) do
      dev_auth_uid_input? || cal_net_page.username? || log_out_link?
      if cal_net_page.username?
        logger.debug 'CAS login page loaded, entering credentials'
        cal_net_page.enter_credentials(Utils.super_admin_username, Utils.super_admin_password)
        wait_until(Utils.short_wait) do
          cal_net_page.logout_conf_heading? || log_out_link?
          if log_out_link?
            logger.debug 'Logged in to Ripley, logging out'
            log_out
          else
            logger.debug 'Logged out of CAS'
          end
        end
      elsif log_out_link?
        logger.debug 'Ripley loaded, logging out'
        log_out
      else
        logger.debug 'Dev auth is already present'
      end
    end
  end
end
