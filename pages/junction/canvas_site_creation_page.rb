require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasSiteCreationPage < CanvasCourseSectionsPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      h2(:page_heading, xpath: '//h2[text()="Create a Site"]')
      paragraph(:access_denied, xpath: '//p[contains(.,"This feature is only available to faculty and staff.")]')

      link(:create_course_site_link, text: 'Create a Course Site')
      paragraph(:course_sites_text, xpath: '//p[contains(text(),"Set up course sites to communicate with and manage the work of students enrolled in your classes.")]')
      paragraph(:no_course_sites_text, xpath: '//p[contains(text(),"It appears that you do not have permissions to create a Course Site in the current or upcoming terms.")]')
      link(:bcourses_support_link, xpath: '//a[contains(text(),"bCourses support")]')

      link(:create_project_site_link, text: 'Create a Project Site')
      link(:projects_learn_more_link, xpath: '//a[contains(., "more about collaboration tools available at UC Berkeley.")]')

      # Loads the LTI tool in the context of a Canvas course site
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      def load_embedded_tool(driver, user)
        logger.info 'Loading embedded version of Create Course Site tool'
        navigate_to "#{Utils.canvas_base_url}/users/#{user.canvas_id}/external_tools/#{JunctionUtils.canvas_create_site_tool}"
        switch_to_canvas_iframe driver
      end

      # Loads standalone site creation page
      def load_standalone_tool
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/embedded/site_creation"
      end

      # Clicks the create course site button and waits for the page to load
      def click_create_course_site
        wait_for_load_and_click create_course_site_link_element
        h1_element(xpath: '//h1[text()="Create a Course Site"]').when_visible Utils.medium_wait
      end

      # Clicks the create project site button
      def click_create_project_site
        wait_for_update_and_click create_project_site_link_element
      end

    end
  end
end
