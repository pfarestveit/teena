require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class MyToolboxPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      button(:view_as_submit_button, id: 'view-as-submit')
      link(:campus_dir_link, id: 'link-to-httpswwwberkeleyedudirectory')
      button(:clear_recent_users_button, id: 'clear-recent-users')
      elements(:view_as_uid_button, :button, id: 'act-as-by-uid')

      # Loads My Toolbox
      def load_page
        logger.info 'Loading My Toolbox page'
        navigate_to "#{JunctionUtils.junction_base_url}/toolbox"
      end

    end
  end
end
