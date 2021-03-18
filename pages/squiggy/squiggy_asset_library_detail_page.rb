class SquiggyAssetLibraryDetailPage

  include PageObject
  include Page
  include Logging
  include SquiggyAssetLibraryMetadataForm

  h2(:asset_title, id: 'asset.title')
  div(:asset_preview, xpath: '//div[starts-with(@id, "asset-preview-image-")]')
  span(:owner_name, xpath: '//span[starts-with(@id, "by-user-")]')
  button(:like_button, id: 'like-asset-btn')
  span(:like_count, id: 'asset-like-count')
  span(:view_count, id: 'asset-view-count')
  span(:comment_count, id: 'asset-comment-count')
  div(:description, xpath: '//h3[text()="Description"]/..')
  # TODO - category

  def wait_for_asset_and_get_id(asset)
    asset_title_element.when_visible Utils.medium_wait
    asset.id = SquiggyUtils.set_asset_id asset
  end

  def visible_asset_metadata
    {
      title: (asset_title if asset_title?),
      owner: (owner_name if owner_name?),
      like_count: (like_count if like_count?),
      view_count: (view_count if view_count?),
      comment_count: (comment_count if comment_count?),
      description: (description.strip if description?)
      # TODO category
    }
  end

  def preview_generated?(asset)
    logger.info "Verifying a preview of type '#{asset.preview_type}' is generated for the asset within #{Utils.short_wait} seconds"
    verify_block do
      logger.debug 'Waiting for preparing preview to go away'
      # TODO - wait for spinner or whatever it is
      (
        case asset.preview_type
        when 'image'
          # some kind of image
        when 'pdf_document'
          # some kind of embedded pdf
        when 'embeddable_link'
          # some king of embedded page
        when 'non_embeddable_link'
          # some kind of image
        when 'embeddable_youtube'
          # some kind of embedded video
        when 'embeddable_vimeo'
          # some kind of embedded video
        when 'embeddable_video'
          # some kind of embedded video
        else
          # some kind of "sorry" message
        end).when_present Utils.short_wait
    end
  end

  # EDIT DETAILS

  button(:edit_details_button, id: 'edit-asset-details-btn')

  # DOWNLOAD ASSET

  link(:download_button, id: 'download-asset-btn')

  def download_asset(asset)
    logger.info "Downloading asset ID #{asset.id}"
    Utils.prepare_download_dir
    wait_for_load_and_click download_asset_link_element
    wait_until(Utils.medium_wait) do
      Dir.entries("#{Utils.download_dir}").length == 3
      download_file_name = Dir.entries("#{Utils.download_dir}").last
      logger.debug "Downloaded file name is '#{download_file_name}'"
      download_file = File.new File.join(Utils.download_dir, download_file_name)
      asset_file = File.new SuiteCUtils.asset_file_path(asset.file_name)
      wait_until(Utils.medium_wait) do
        logger.debug "The downloaded file size is currently #{download_file.size}, waiting for it to reach #{asset_file.size}"
        download_file.size == asset_file.size
      end
      download_file_name
    end
  end

  # DELETE ASSET

  button(:delete_button, id: 'delete-asset-btn')
  button(:delete_confirm_button, id: 'confirm-delete-btn')
  button(:delete_cancel_button, id: 'cancel-delete-btn')

  def delete_asset(asset)
    logger.info "Deleting asset ID #{asset.id}"
    wait_for_update_and_click delete_button_element
    wait_for_update_and_click delete_confirm_button_element
    delete_asset_button_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
  end

  # ADD COMMENT

  text_area(:comment_input, id: 'comment-body-textarea')
  button(:comment_add_button, id: 'save-comment-btn')

  def comment_el_by_id(comment)
    div_element(id: "comment-#{comment.id}")
  end

  def comment_el_by_body(comment)
    div_element(xpath: "//div[contains(text(), '#{comment.body}')]")
  end

  def comment_body_el(comment)
    div_element(id: "comment-#{comment.id}-body")
  end

  def add_comment(asset, comment)
    logger.info "Adding the comment '#{comment.body}'"
    scroll_to_bottom
    enter_squiggy_text(comment_input_element, comment.body)
    wait_until(Utils.short_wait) { comment_add_button_element.enabled? }
    wait_for_update_and_click comment_add_button_element
    comment_el_by_body(comment).when_visible Utils.short_wait
    SquiggyUtils.set_comment_id comment
  end

  def visible_comment(comment)
    {
      # TODO - body
      # TODO - commenter name
    }
  end

  def commenter_link(comment)
    # TODO
  end

  # REPLY TO COMMENT

  def reply_button_el(comment)
    button_element(id: "reply-to-comment-#{comment.id}-btn")
  rescue Selenium::WebDriver::Error::NoSuchElementError
    nil
  end

  def click_reply_button(comment)
    wait_for_update_and_click reply_button_element(comment)
  end

  def reply_input_el(comment)
    text_area_element(id: "reply-to-comment-#{comment.id}-body-textarea")
  end

  def reply_to_comment(asset, comment, reply_comment)
    logger.info "Replying '#{reply_comment.body}'"
    click_reply_button comment
    enter_squiggy_text(reply_input_el(comment), reply_comment.body)
    wait_for_update_and_click comment_add_button_element
    comment_el_by_body(reply_comment).when_visible Utils.short_wait
    SquiggyUtils.set_comment_id reply_comment
  end

  # EDIT COMMENT / REPLY

  def edit_button_element(comment)
    button_element(id: "edit-comment-#{comment.id}-btn")
  rescue Selenium::WebDriver::Error::NoSuchElementError
    nil
  end

  def click_edit_button(comment)
    wait_for_load_and_click edit_button_element(comment)
  end

  def edit_comment(asset, comment)
    logger.info "Editing comment id #{comment.id}. New comment is '#{comment.body}'"
    click_edit_button comment
    enter_squiggy_text(comment_input_element, comment.body)
    wait_for_update_and_click_js save_edit_button_element(index)
    wait_until(Utils.short_wait) { comment_body(index) == comment.body }
    add_event(event, EventType::MODIFY, asset.id)
    add_event(event, EventType::EDIT_COMMENT, asset.id)
  end

  # DELETE COMMENT

  def delete_button_element(comment)
    button_element(id: "delete-comment-#{comment.id}-btn")
  rescue Selenium::WebDriver::Error::NoSuchElementError
    nil
  end

  def delete_comment(asset, comment)
    alert { wait_for_load_and_click delete_button_element(comment) }
    asset.comments.delete comment
    sleep Utils.click_wait
  end

end
