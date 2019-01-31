require_relative '../util/spec_helper'

module Page

  class GooglePage

    include PageObject
    include Logging
    include Page

    # LOGIN / LOGOUT

    h1(:welcome_heading, :id => 'headingText')
    link(:sign_in_link, :xpath => '//a[text()="Sign In"]')
    link(:profile_switcher, :xpath => '//div[@aria-label="Switch account"]')
    button(:use_another_acct_link, :xpath => '//div[text()="Use another account"]')
    text_area(:username_input, :id => 'identifierId')
    button(:username_next_button, :id => 'identifierNext')
    text_area(:password_input, :name => 'password')
    button(:password_next_button, :id => 'passwordNext')
    button(:done_button, :xpath => '//div[@role="button"][contains(.,"Done")]')

    link(:account_link, :xpath => '//a[contains(@href,"SignOutOptions")]')
    link(:sign_out_link, :text => 'Sign out')

    # EMAIL
    button(:compose_email_button, :xpath => '//div[@role="button"][contains(.,"Compose")]')
    link(:new_message_heading, :xpath => '//h2[contains(.,"New Message")]')
    link(:recipient, :xpath => 'div[text()="Recipients"]')
    text_area(:to, :xpath => '//textarea[@aria-label="To"]')
    text_area(:subject, :name => 'subjectbox')
    text_area(:body, :xpath => '//div[@aria-label="Message Body"]')

    button(:send_email_button, :xpath => '//div[@role="button"][contains(.,"Send")]')
    link(:mail_sent_link, :xpath => '//span[text()="Message sent."]')

    button(:select_all_msgs_button, :xpath => '//div[@role="button"][@aria-label="Select"]//span[@role="checkbox"]')
    button(:delete_button, :xpath => '//div[@role="button"][@aria-label="Delete"]')
    div(:no_msgs_msg, :xpath => '//div[text()="Your Primary tab is empty."]')

    # Loads Gmail
    def load_gmail
      logger.info 'Loading Gmail'
      navigate_to 'https://mail.google.com'
    end

    # Returns the account selector element for a user
    # @param username [String]
    # @return [PageObject::Elements:Div]
    def account_selector(username)
      div_element(:xpath => "//div[@role='button'][contains(.,'#{username}')]")
    end

    # Logs a user into Gmail, ensuring any previous session is ended
    # @param username [String]
    def log_in(username)
      tries ||= Utils.short_wait
      # Make sure no account is currently logged in
      begin
        wait_until(1) { welcome_heading_element.visible? || account_link? || sign_in_link? }
        if account_link?
          log_out
        elsif sign_in_link?
          sign_in_link_element.click
        end
        welcome_heading_element.when_visible(1)
      rescue
        (tries -= 1).zero? ? fail : retry
      end
      # Make sure the right account is selected for login
      wait_for_update_and_click profile_switcher_element if password_input?
      begin
        account_selector(username).when_visible(1)
        account_selector(username).click
      rescue
        sleep Utils.click_wait
        use_another_acct_link_element.click if use_another_acct_link?
        wait_for_element_and_type(username_input_element, username)
        wait_for_update_and_click username_next_button_element
      end
      wait_for_element_and_type(password_input_element, Utils.gmail_password)
      wait_for_update_and_click password_next_button_element
      compose_email_button_element.when_visible Utils.short_wait rescue done_button
      compose_email_button_element.when_visible Utils.short_wait
    end

    # Deletes all visible message in the inbox
    def delete_all_msgs
      wait_for_load_and_click select_all_msgs_button_element
      wait_for_update_and_click delete_button_element
      no_msgs_msg_element.when_present Utils.short_wait
    end

    # Logs out of Gmail
    def log_out
      wait_for_update_and_click account_link_element
      wait_for_update_and_click sign_out_link_element
    end

    # Logs the user in to Gmail, deletes the visible inbox messages, and sends an email
    # @param username [String]
    # @param recipient [String]
    # @param subject [String]
    # @param body [String]
    def send_email(username, recipient, subject, body = nil)
      load_gmail
      log_in username
      delete_all_msgs
      logger.info "Sending an email from #{username} to #{recipient} with the subject #{subject}"
      wait_for_load_and_click compose_email_button_element
      wait_for_update_and_click new_message_heading_element
      wait_for_update_and_click new_message_heading_element
      wait_for_update_and_click recipient_element if self.recipient_element.visible?
      wait_for_element_and_type(to_element, recipient)
      self.subject_element.value = subject
      self.body_element.value = body if body
      wait_for_update_and_click send_email_button_element
      mail_sent_link_element.when_present Utils.short_wait
    end

    # Verifies that an email to a mailing list was sent successfully
    # @param subject [String]
    # @return [boolean]
    def email_received?(subject)
      logger.info 'Waiting for an email to appear'
      verify_block { cell_element(:xpath => "//td[contains(.,\"#{subject}\")][not(contains(.,\"Undeliverable\"))]").when_visible Utils.medium_wait }
    end

    # Verifies that an email to a mailing list was rejected
    # @param user [User]
    # @return [boolean]
    def email_bounced?(user)
      logger.info 'Waiting for an email to be rejected'
      verify_block { cell_element(:xpath => "//td[contains(.,\"The following message could not be delivered because the email address #{user.email} is not authorized to send messages to the list\")]").when_visible Utils.medium_wait }
    end

  end
end
