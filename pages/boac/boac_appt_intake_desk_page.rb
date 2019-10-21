require_relative '../../util/spec_helper'

class BOACApptIntakeDeskPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACApptIntakeDesk

  button(:new_appt_button, id: 'btn-create-appointment')

  # Loads the appointment intake desk for a given department
  # @param dept [BOACDepartments]
  def load_page(dept)
    navigate_to "#{BOACUtils.base_url}/appt/desk/#{dept.code.downcase}"
  end

  # Clicks the new appointment button on the intake desk
  def click_new_appt
    wait_for_update_and_click new_appt_button_element
    student_name_input_element.when_visible 1
  end

end
