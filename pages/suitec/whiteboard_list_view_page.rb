require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class WhiteboardListViewPage

      include PageObject
      include Page
      include Logging
      include SuiteCPages

      # Loads Whiteboards tool and switches browser focus to the tool iframe
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param event [Event]
      def load_page(driver, url, event = nil)
        navigate_to url
        wait_until { title == "#{LtiTools::WHITEBOARDS.name}" }
        hide_canvas_footer_and_popup
        switch_to_canvas_iframe driver
        add_event(event, EventType::NAVIGATE)
        add_event(event, EventType::VIEW)
        add_event(event, EventType::LAUNCH_WHITEBOARDS)
        add_event(event, EventType::LIST_WHITEBOARDS)
      end

      # CREATE WHITEBOARD

      link(:create_first_whiteboard_link, text: 'Create your first whiteboard')
      link(:add_whiteboard_link, xpath: '//span[text()="Whiteboard"]/..')
      text_area(:new_title_input, id: 'whiteboards-create-title')
      text_area(:new_collaborator_input, xpath: '//label[text()="Collaborators"]/following-sibling::div//input')
      button(:create_whiteboard_button, xpath: '//button[text()="Create whiteboard"]')
      link(:cancel_new_whiteboard_link, text: 'Cancel')

      div(:title_req_msg, xpath: '//div[text()="Please enter a title"]')
      div(:title_max_length_msg, xpath: '//div[text()="A title can only be 255 characters long"]')
      div(:no_collaborators_msg, xpath: '//div[text()="A whiteboard requires at least 1 collaborator"]')

      # Clicks the 'add whiteboard' link
      def click_add_whiteboard
        wait_for_update_and_click add_whiteboard_link_element
      end

      # Enters text in the whiteboard title input
      # @param title [String]
      def enter_whiteboard_title(title)
        wait_for_element_and_type_js(new_title_input_element, title)
      end

      # Returns the element that allows selection of a user as a whiteboard collaborator
      # @param user [User]
      # @return [PageObject::Elements::Element]
      def collaborator_option_link(user)
        button_element(xpath: "//li[contains(@class,'select-dropdown-optgroup-option')][contains(text(),'#{user.full_name}')]")
      end

      # Returns the element indicating that a user is an existing whiteboard collaborator
      # @param user [User]
      # @return [PageObject::Elements::Element]
      def collaborator_name(user)
        list_item_element(xpath: "//li[contains(@class,'select-search-list-item_selection')]/span[contains(text(),'#{user.full_name}')]")
      end

      # Selects a given set of users as whiteboard collaborators
      # @param users [Array<User>]
      def enter_whiteboard_collaborators(users)
        users.each do |user|
          wait_for_element_and_type_js(new_collaborator_input_element, user.full_name)
          wait_for_update_and_click collaborator_option_link(user)
          wait_until(Utils.short_wait) { collaborator_name user }
        end
      end

      # Clicks the create button to complete creation of a whiteboard
      def click_create_whiteboard
        wait_for_update_and_click create_whiteboard_button_element
      end

      # Combines methods to create a new whiteboard and obtain its ID
      # @param whiteboard [Whiteboard]
      # @param event [Event]
      def create_whiteboard(whiteboard, event = nil)
        logger.info "Creating a new whiteboard named '#{whiteboard.title}'"
        click_add_whiteboard
        enter_whiteboard_title whiteboard.title
        enter_whiteboard_collaborators whiteboard.collaborators
        click_create_whiteboard
        verify_first_whiteboard whiteboard
        add_event(event, EventType::CREATE, whiteboard.id)
        add_event(event, EventType::VIEW)
        add_event(event, EventType::CREATE_WHITEBOARD)
        add_event(event, EventType::LIST_WHITEBOARDS)
      end

      # OPEN WHITEBOARD

      h2(:launch_failure, xpath: '//h2[text()="Launch failure"]')

      # Combines methods to create a new whiteboard and then open it
      # @param driver [Selenium::WebDriver]
      # @param whiteboard [Whiteboard]
      # @param event [Event]
      def create_and_open_whiteboard(driver, whiteboard, event = nil)
        create_whiteboard(whiteboard, event)
        open_whiteboard(driver, whiteboard, event)
      end

      # Opens a whiteboard using its ID and shifts browser focus to the new window
      # @param driver [Selenium::WebDriver]
      # @param whiteboard [Whiteboard]
      # @param event [Event]
      def open_whiteboard(driver, whiteboard, event = nil)
        logger.info "Opening whiteboard ID #{whiteboard.id}"
        click_whiteboard_link whiteboard
        shift_to_whiteboard_window(driver, whiteboard) if driver.browser == 'chrome'
        add_event(event, EventType::VIEW, whiteboard.id)
        add_event(event, EventType::VIEW, 'Chat')
        add_event(event, EventType::OPEN_WHITEBOARD, whiteboard.id)
        add_event(event, EventType::GET_CHAT_MSG, whiteboard.id)
      end

      # WHITEBOARDS LIST VIEW

      elements(:list_view_whiteboard, :list_item, xpath: '//li[@data-ng-repeat="whiteboard in whiteboards"]')
      elements(:list_view_whiteboard_title, :div, xpath: '//li[@data-ng-repeat="whiteboard in whiteboards"]//div[@class="col-list-item-metadata"]/span')
      elements(:list_view_whiteboard_link, :link, xpath: '//li[@data-ng-repeat="whiteboard in whiteboards"]//a')

      # Returns an array of all whiteboard titles in list view
      # @return [Array<String>]
      def visible_whiteboard_titles
        list_view_whiteboard_title_elements.map &:text
      end

      # Returns the ID of the first whiteboard in list view by extracting the ID from the whiteboard link href
      # @return [String]
      def get_first_whiteboard_id
        wait_until { list_view_whiteboard_link_elements.any? }
        href = list_view_whiteboard_link_elements.first.attribute('href')
        whiteboard_url = href.split('?').first
        whiteboard_url.sub("#{SuiteCUtils.suite_c_base_url}/whiteboards/", '')
      end

      # Verifies that the title of the first whiteboard in list view matches that of a given whiteboard object
      # @param whiteboard [Whiteboard]
      def verify_first_whiteboard(whiteboard)
        # Pause to allow DOM update to complete
        sleep 1
        logger.debug "Verifying list view whiteboard title includes '#{whiteboard.title}'"
        wait_until(Utils.short_wait) { list_view_whiteboard_title_elements[0].text.include? whiteboard.title }
        logger.info "New whiteboard ID is #{whiteboard.id = get_first_whiteboard_id}"
      end

      # Finds a whiteboard link by its ID and then clicks to open it
      # @param whiteboard [Whiteboard]
      def click_whiteboard_link(whiteboard)
        wait_until { list_view_whiteboard_link_elements.any? }
        wait_for_update_and_click_js (list_view_whiteboard_link_elements.find { |link| link.attribute('href').include?("/whiteboards/#{whiteboard.id}?") })
      end

      # SEARCH

      text_area(:simple_search_input, id: 'whiteboards-search')
      button(:simple_search_button, xpath: '//button[@title="Search"]')
      button(:open_advanced_search_button, xpath: '//button[@title="Advanced search"]')
      text_area(:advanced_search_keyword_input, id: 'whiteboards-search-keywords')
      select_list(:advanced_search_user_select, id: 'whiteboards-search-user')
      checkbox(:include_deleted_cbx, id: 'whiteboards-search-include-deleted')
      link(:cancel_search_link, text: 'Cancel')
      button(:advanced_search_button, xpath: '//button[text()="Search"]')
      span(:no_results_msg, xpath: '//span[contains(text(),"No matching whiteboards were found.")]')

      # Performs a simple whiteboard search
      # @param string [String]
      # @param event [Event]
      def simple_search(string, event = nil)
        logger.info "Performing simple search for '#{string}'"
        if cancel_search_link_element.visible?
          cancel_search_link
          add_event(event, EventType::VIEW)
        end
        wait_for_element_and_type_js(simple_search_input_element, string)
        sleep 1
        wait_for_update_and_click_js simple_search_button_element
        add_event(event, EventType::SEARCH)
        add_event(event, EventType::SEARCH_WHITEBOARDS, string)
      end

      # Performs an advanced whiteboard search
      # @param string [String]
      # @param user [User]
      # @param inc_deleted [boolean]
      # @param event [Event]
      def advanced_search(string, user, inc_deleted, event = nil)
        logger.info 'Performing advanced search'
        open_advanced_search_button unless advanced_search_keyword_input_element.visible?
        logger.debug "Search keyword is '#{string}'"
        string.nil? ?
            wait_for_element_and_type_js(advanced_search_keyword_input_element, '') :
            wait_for_element_and_type_js(advanced_search_keyword_input_element, string)
        sleep 1
        if user.nil?
          self.advanced_search_user_select = 'Collaborator'
        else
          logger.debug "User is '#{user.full_name}'"
          self.advanced_search_user_select = user.full_name
          sleep 1
        end
        inc_deleted ? check_include_deleted_cbx : uncheck_include_deleted_cbx
        wait_for_update_and_click_js advanced_search_button_element
        add_event(event, EventType::SEARCH)
        add_event(event, EventType::SEARCH_WHITEBOARDS, string)
      end

    end
  end
end
