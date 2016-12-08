require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class MyDashboardPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      # Loads My Dashboard
      def load_page
        logger.info 'Loading My Dashboard page'
        navigate_to "#{Utils.calcentral_base_url}/dashboard"
      end

    end
  end
end
