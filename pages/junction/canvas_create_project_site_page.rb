require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasCreateProjectSitePage < CanvasSiteCreationPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      text_area(:site_name_input, id: 'bc-page-create-project-site-name')
      button(:create_site_button, xpath: '//button[contains(.,"Create a Project Site")]')
      button(:cancel_button, xpath: '//button[contains(.,"Cancel")]')
      paragraph(:name_too_long_msg, xpath: '//p[contains(.,"Project site name must be no more than 255 characters in length")]')

      # Loads the LTI tool in the Junction context
      def load_standalone_tool
        logger.info 'Loading standalone version of Create Course Site tool'
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/create_project_site"
      end

      def enter_site_name(name)
        logger.info "Entering project site name '#{name}'"
        wait_for_element_and_type(site_name_input_element, name)
      end

      def create_project_site(name)
        logger.info 'Creating a project site'
        enter_site_name name
        wait_for_update_and_click create_site_button_element
      end

    end
  end
end
