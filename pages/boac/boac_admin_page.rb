require_relative '../../util/spec_helper'

class BOACAdminPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  link(:admins_link, :text => 'Admins')
  checkbox(:demo_mode_toggle, :id => 'toggle-demo-mode')
  link(:asc_tab, :text => 'Athletics Study Center')
  link(:coe_tab, :text => 'College of Engineering')
  link(:physics_tab, :text => 'Department of Physics')
  link(:admins_tab, :text => 'Admins')
  h2(:status_heading, :xpath => '//h2[text()="Status"]')

  # Loads the admin page
  def load_page
    navigate_to "#{BOACUtils.base_url}/admin"
  end

end
