require_relative '../../util/spec_helper'

class RipleySplashPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  button(:header_button, xpath: '//header//button')

  def load_page
    navigate_to RipleyUtils.base_url
  end

  # Log in

  button(:cal_net_login_button, id: 'cas-auth-submit-button')

  def click_cal_net_login_button
    wait_for_load_and_click cal_net_login_button_element
  end

  def log_in_via_cal_net(cal_net_page, username, password)
    logger.info "Logging in #{username} via CalNet"
    click_cal_net_login_button
    cal_net_page.enter_credentials(username, password)
    header_button_element.when_present Utils.short_wait
  end

  # Dev Auth

  text_field(:dev_auth_uid_input, id: 'basic-auth-uid')
  text_field(:dev_auth_password_input, id: 'basic-auth-password')
  text_field(:dev_auth_course_input, id: 'basic-auth-canvas-course-id')
  button(:dev_auth_log_in_button, id: 'basic-auth-submit-button')

  def dev_auth(uid, course_site = nil, cal_net = nil)
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
    dev_auth_uid_input_element.when_present Utils.medium_wait
    dev_auth_uid_input_element.send_keys uid
    dev_auth_password_input_element.send_keys RipleyUtils.dev_auth_password
    dev_auth_course_input_element.send_keys course_site.site_id if course_site
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

  link(:jobs_link, text: 'Jobs')

  def click_jobs_link
    logger.info 'Clicking Jobs link'
    wait_for_load_and_click jobs_link_element
    hide_header
  end

end
