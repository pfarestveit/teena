require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class AssetLibraryManageAssetsPage < AssetLibraryListViewPage

      include PageObject
      include Logging
      include Page
      include SuiteCPages

      # CUSTOM CATEGORIES

      text_area(:custom_category_input, id: 'assetlibrary-manageassets-create-name')
      button(:add_custom_category_button, xpath: '//button[text()="Add"]')
      unordered_list(:custom_categories_list, xpath: '//h3[text()="Custom Categories"]/following-sibling::ul')
      elements(:custom_category, :list_item, xpath: '//h3[text()="Custom Categories"]/following-sibling::ul/li')
      elements(:custom_category_title, :span, xpath: '//h3[text()="Custom Categories"]/following-sibling::ul/li//span[@data-ng-bind="category.title"]')
      elements(:edit_category_form, :form, class: 'assetlibrary-manageassets-edit-form')
      div(:category_title_error_msg, xpath: '//div[contains(.,"Please enter a category")]')

      # Loads the asset library and adds a collection of custom categories
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param category_titles [Array<String>]
      # @param event [Event]
      def add_custom_categories(driver, url, category_titles, event = nil)
        load_page(driver, url, event)
        click_manage_assets_link
        category_titles.each do |category_title|
          logger.info "Adding category called #{category_title}"
          wait_for_element_and_type(custom_category_input_element, category_title)
          wait_for_update_and_click add_custom_category_button_element
          sleep 2
          wait_until(Utils.short_wait) { custom_category_titles.include? category_title }
        end
      end

      # Returns an array of existing custom category titles
      # @return [Array<String>]
      def custom_category_titles
        custom_categories_list_element.when_visible
        sleep 1
        custom_category_title_elements.map &:text
      end

      # Returns the index of a given custom category title in the list of titles
      # @param category_title [String]
      # @return [Integer]
      def custom_category_index(category_title)
        wait_until(Utils.short_wait) { custom_category_title_elements.any? }
        custom_category_titles.index category_title
      end

      # Returns the asset count shown for a custom category at a given index
      # @param index [Integer]
      # @return [String]
      def custom_category_asset_count(index)
        div_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//small").text
      end

      # Clicks the edit button for a custom category at a given index
      # @param index [Integer]
      def click_edit_custom_category(index)
        wait_for_update_and_click_js button_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//button[@title='Edit this category']")
      end

      # Enters a category title while editing a custom category at a given index
      # @param index [Integer]
      # @param new_title [String]
      def enter_edited_category_title(index, new_title)
        logger.debug "Entering new title '#{new_title}' for category at index #{index}"
        wait_for_element_and_type_js(text_area_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//input[@id='assetlibrary-manageassets-edit-name']"), new_title)
      end

      # Clicks the 'cancel' button when editing a custom category at a given index
      # @param index [Integer]
      def click_cancel_custom_category_edit(index)
        wait_for_update_and_click_js button_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//button[text()='Cancel']")
      end

      # Clicks the 'save' button when editing a custom category at a given index
      # @param index [Integer]
      def click_save_custom_category_edit(index)
        wait_for_update_and_click_js button_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//button[text()='Save Changes']")
      end

      # Deletes a custom category with a given title
      # @param category_title [String]
      def delete_custom_category(category_title)
        logger.info "Deleting category called #{category_title}"
        wait_until(Utils.short_wait) { custom_category_titles.include? category_title }
        delete_button = button_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{custom_category_index(category_title) + 1}]//button[@title='Delete this category']")
        confirm(true) { wait_for_update_and_click_js delete_button }
        sleep 2
      end

      # CANVAS CATEGORIES

      elements(:canvas_category, :list_item, xpath: '//h3[text()="Assignments"]/following-sibling::ul/li')
      elements(:canvas_category_title, :span, xpath: '//h3[text()="Assignments"]/following-sibling::ul/li//span[@data-ng-bind="category.title"]')

      # Waits for the Canvas poller to import a Canvas assignment as a category
      # @param driver [Selenium::WebDriver]
      # @param asset_library_url [String]
      # @param assignment [Assignment]
      def wait_for_canvas_category(driver, asset_library_url, assignment)
        logger.info "Checking if the Canvas assignment #{assignment.title} has appeared on the Manage Categories page yet"
        tries ||= SuiteCUtils.poller_retries
        load_page(driver, asset_library_url)
        click_manage_assets_link
        wait_until(3) { canvas_category_elements.any? && (canvas_category_title_elements.map &:text).include?(assignment.title) }
        logger.debug 'The assignment category has appeared'
      rescue
        logger.debug "The assignment category has not yet appeared, will retry in #{Utils.short_wait} seconds"
        sleep Utils.short_wait
        retry unless (tries -= 1).zero?
      end

      # Returns the checkbox element for toggling Canvas assignment sync
      # @param assignment [Assignment]
      # @return [PageObject::Elements::CheckBox]
      def assignment_sync_cbx(assignment)
        checkbox_element(xpath: "//span[text()='#{assignment.title}']/../following-sibling::div//input")
      end

      # Enables syncing for a given assignment
      # @param assignment [Assignment]
      def enable_assignment_sync(assignment)
        logger.info "Enabling Canvas assignment sync for #{assignment.title}"
        assignment_sync_cbx(assignment).when_visible Utils.short_wait
        assignment_sync_cbx(assignment).checked? ?
            logger.debug('Assignment sync is already enabled, moving on') :
            wait_for_update_and_click_js(assignment_sync_cbx assignment)
      end

      # Disables syncing for a given assignment
      # @param assignment [Assignment]
      def disable_assignment_sync(assignment)
        logger.info "Disabling Canvas assignment sync for #{assignment.title}"
        assignment_sync_cbx(assignment).when_visible Utils.short_wait
        assignment_sync_cbx(assignment).checked? ?
            wait_for_update_and_click_js(assignment_sync_cbx assignment) :
            logger.debug('Assignment sync is already disabled, moving on')
      end

      # ASSET MIGRATION

      select_list(:migrate_assets_select, id: 'assetlibrary-manageassets-migrate-coursesite')
      button(:migrate_assets_button, xpath: '//button[text()="Migrate assets"]')
      div(:migration_started_msg, xpath: '//div[contains(.,"Your migration has started. Copied assets will appear in the Asset Library of the destination course.")]')
      div(:no_courses_msg, xpath: '//h3["Migrate Assets"]/following-sibling::div/div[contains(.,"You are not an instructor in any other course sites using the Asset Library.")]')

      # Kicks off asynchronous asset migration from one asset library to another
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param destination_course [Course]
      def migrate_assets(driver, url, destination_course)
        logger.info "Migrating assets to '#{destination_course.title}', ID '#{destination_course.site_id}'"
        load_page(driver, url)
        click_manage_assets_link
        wait_for_element_and_select_js(migrate_assets_select_element, destination_course.title)
        wait_for_update_and_click_js migrate_assets_button_element
        migration_started_msg_element.when_present Utils.medium_wait
      end

      # Makes a number of attempts to find an asset in an asset library following asynchronous asset migration
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param asset [Asset]
      # @param user [User]
      # @return [boolean]
      def asset_migrated?(driver, url, asset, user)
        tries ||= 3
        load_page(driver, url)
        advanced_search(asset.title, nil, user, asset.type, nil)
        verify_first_asset(user, asset)
        true
      rescue
        logger.debug "The migrated asset has not yet appeared, will retry in #{Utils.short_wait} seconds"
        retry unless (tries -= 1).zero?
        false
      end

    end
  end
end
