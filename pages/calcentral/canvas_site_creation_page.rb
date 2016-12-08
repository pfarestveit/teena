require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class CanvasSiteCreationPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      h2(:page_heading, xpath: '//h2[text()="Create a Site"]')

      link(:create_course_site_link, text: 'Create a Course Site')
      paragraph(:course_sites_text, xpath: '//p[contains(text(),"Set up course sites to communicate with and manage the work of students enrolled in your classes.")]')
      paragraph(:no_course_sites_text, xpath: '//p[contains(text(),"It appears that you do not have permissions to create a Course Site in the current or upcoming terms.")]')
      link(:bcourses_support_link, xpath: '//a[contains(text(),"bCourses support")]')

      link(:create_project_site_link, text: 'Create a Project Site')
      paragraph(:projects_sites_text, xpath: '//p[contains(text(),"Share files and collaborate with your project or teaching team. Projects are best suited for instructors and GSIs who already use bCourses for their courses.")]')
      link(:projects_learn_more_link, xpath: '//a[contains(text(), "Learn more about your online collaboration options.")]')

      # Loads site creation page
      def load_page
        navigate_to "#{Utils.calcentral_base_url}/canvas/embedded/site_creation"
        page_heading_element.when_visible Utils.medium_wait
      end

      # Clicks the create course site button and waits for the page to load
      # @param course_site_page [Page::CalCentralPages::CanvasCreateCourseSitePage]
      def click_create_course_site(course_site_page)
        wait_for_page_update_and_click create_course_site_link_element
        course_site_page.page_heading_element.when_visible Utils.medium_wait
      end

      # Clicks the create project site button
      def click_create_project_site
        wait_for_page_update_and_click create_project_site_link_element
      end

      # Masquerades as a user if necessary and navigates from the Canvas homepage to the create a course site page
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      # @param instructor [User]
      # @param canvas [Page::CanvasPage]
      # @param create_course_site [Page::CalCentralPages::CanvasCreateCourseSitePage]
      def choose_course_site(driver, course, instructor, canvas, create_course_site)
        canvas.stop_masquerading if canvas.stop_masquerading_link?
        canvas.masquerade_as(instructor, course) if course.create_site_workflow == 'masquerade'
        canvas.load_homepage
        canvas.click_create_site driver
        click_create_course_site create_course_site
      end

    end
  end
end
