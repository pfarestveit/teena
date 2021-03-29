class SquiggyLoginPage

  include PageObject
  include Page
  include Logging

  text_field(:user_id_input, id: 'uid-input')
  text_field(:password_input, id: 'password-input')
  button(:log_in_button, id: 'btn-dev-auth-login')

  def load_page
    logger.info 'Hello!  Loading the Squiggy login page'
    navigate_to "#{SquiggyUtils.base_url}/squiggy"
  end

  def log_in(uid, password)
    logger.info "Logging in as UID #{uid}"
    wait_for_element_and_type(user_id_input_element, uid)
    wait_for_element_and_type(password_input_element, password)
    wait_for_update_and_click log_in_button_element
  end

end
