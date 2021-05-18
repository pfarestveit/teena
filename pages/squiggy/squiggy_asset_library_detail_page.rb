class SquiggyAssetLibraryDetailPage < SquiggyAssetLibraryListViewPage

  include PageObject
  include Page
  include Logging
  include SquiggyAssetLibraryMetadataForm

  h2(:asset_title, id: 'asset.title')
  div(:asset_preview, xpath: '//div[starts-with(@id, "asset-preview-image-")]')
  button(:like_button, id: 'like-asset-btn')
  span(:like_count, id: 'asset-like-count')
  span(:view_count, id: 'asset-view-count')
  span(:comment_count, id: 'asset-comment-count')
  div(:description, xpath: '//h3[text()="Description"]/..')
  # TODO - category

  def load_asset_detail(test, asset)
    navigate_to "#{test.course.asset_library_url}#suitec_assetId=#{asset.id}"
    switch_to_canvas_iframe
    wait_for_asset_detail asset
  end

  def wait_for_asset_detail(asset)
    wait_until(Utils.short_wait) { asset_title.include? "#{asset.title}" }
  end

  def wait_for_asset_and_get_id(asset)
    asset_title_element.when_visible Utils.medium_wait
    asset.id = SquiggyUtils.set_asset_id asset
  end

  def owner_el(asset)
    link_element(xpath: "//a[contains(text(), '#{asset.owner.full_name}')]")
  end

  def category_el(asset)
    link_element(text: asset.category)
  end

  def source_el(asset)
    link_element(text: asset.url)
  end

  def visible_asset_metadata(asset)
    asset_title_element.when_visible Utils.short_wait
    {
      title: (asset_title if asset_title?),
      owner: (owner_el(asset).text.strip if owner_el(asset).exists?),
      like_count: (like_count if like_count?),
      view_count: (view_count if view_count?),
      comment_count: (comment_count if comment_count?),
      description: (description.strip if description?)
      # TODO category
    }
  end

  # PREVIEW

    div(:preparing_preview_msg, xpath: '//div[contains(text(), "Preparing a preview")]')

  def preview_generated?(asset)
    logger.info "Verifying a preview of type '#{asset.preview_type}' is generated for the asset within #{Utils.medium_wait} seconds"
    verify_block do
      if preparing_preview_msg?
        start = Time.now
        logger.debug 'Waiting for preparing preview to go away'
        preparing_preview_msg_element.when_not_present Utils.medium_wait
        logger.debug "PERF - Preview prepared in #{Time.now - start} seconds"
      end
      preview_xpath = "//div[@class='assetlibrary-item-preview']"
      (
        case asset.preview_type
        when 'image', 'non_embeddable_link'
          div_element(xpath: "#{preview_xpath}//div[contains(@class, 'v-image')]")
        when 'pdf_document'
          div_element(xpath: '//iframe[@class="preview-document"]')
        when 'embeddable_link', 'embeddable_youtube', 'embeddable_vimeo'
          div_element(xpath: "#{preview_xpath}//iframe[contains(@src,'#{asset.url.sub(/https?\:(\/\/)(www.)?/, '').split('/').first}')]")
        when 'embeddable_video'
          video_element(xpath: '//video')
        else
          div_element(xpath: '//div[contains(text(),"No preview available")]')
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
    wait_for_load_and_click download_button_element
    wait_until(Utils.medium_wait) do
      Dir.entries("#{Utils.download_dir}").length == 3
      download_file_name = Dir.entries("#{Utils.download_dir}").find { |f| !%w(. ..).include? f }
      logger.debug "Downloaded file name is '#{download_file_name}'"
      download_file = File.new File.join(Utils.download_dir, download_file_name)
      wait_until(Utils.medium_wait) do
        logger.debug "The downloaded file size is currently #{download_file.size}, waiting for it to reach #{asset.size}"
        download_file.size == asset.size
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

  # LIKE

  # TODO

  # ADD COMMENT

  text_area(:comment_input, id: 'comment-body-textarea')
  button(:comment_add_button, id: 'create-comment-btn')

  def comment_el_by_id(comment)
    div_element(id: "comment-#{comment.id}")
  end

  def comment_el_by_body(comment)
    div_element(xpath: "//div[contains(text(), '#{comment.body}')]")
  end

  def comment_body_el(comment)
    div_element(id: "comment-#{comment.id}-body")
  end

  def add_comment(comment)
    logger.info "Adding the comment '#{comment.body}'"
    scroll_to_bottom
    enter_squiggy_text(comment_input_element, comment.body)
    wait_until(Utils.short_wait) { comment_add_button_element.enabled? }
    wait_for_update_and_click comment_add_button_element
    comment_el_by_body(comment).when_visible Utils.short_wait
    comment.set_comment_id
    visible_comment comment
  end

  def visible_comment(comment)
    body_el = div_element(id: "comment-#{comment.id}-body")
    commenter_el = div_element(id: "comment-#{comment.id}-user-name")
    {
      body: (body_el.text.strip if body_el.exists?),
      commenter: (commenter_el.text.strip if commenter_el.exists?)
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
    wait_for_update_and_click_js reply_button_el(comment)
  end

  def reply_input_el(comment)
    text_area_element(id: "reply-to-comment-#{comment.id}-body-textarea")
  end

  def reply_cancel_button
    button_element(id: 'cancel-reply-btn')
  end

  def reply_save_button
    button_element(id: 'save-reply-btn')
  end

  def reply_to_comment(comment, reply_comment)
    logger.info "Replying '#{reply_comment.body}'"
    click_reply_button comment
    enter_squiggy_text(reply_input_el(comment), reply_comment.body)
    wait_for_update_and_click_js reply_save_button
    comment_el_by_body(reply_comment).when_visible Utils.short_wait
    reply_comment.set_comment_id
  end

  def click_cancel_reply(comment)
    logger.info 'Clicking reply Cancel button'
    wait_for_update_and_click reply_cancel_button
    reply_input_el(comment).when_not_present 1
  end

  # EDIT COMMENT / REPLY

  def edit_button(comment)
    button_element(id: "edit-comment-#{comment.id}-btn")
  end

  def cancel_edit_button
    button_element(id: 'cancel-comment-edit-btn')
  end

  def save_edit_button
    button_element(id: 'save-comment-btn')
  end

  def click_edit_button(comment)
    wait_for_load_and_click edit_button(comment)
  end

  def edit_comment_text_area(comment)
    text_area_element(id: "comment-#{comment.id}-body-textarea")
  end

  def click_cancel_edit_button
    wait_for_update_and_click cancel_edit_button
    cancel_edit_button.when_not_present 1
  end

  def edit_comment(comment)
    logger.info "Editing comment id #{comment.id}. New comment is '#{comment.body}'"
    click_edit_button comment
    enter_squiggy_text(edit_comment_text_area(comment), comment.body)
    wait_for_update_and_click save_edit_button
    comment_el_by_body(comment).when_visible Utils.short_wait
  end

  # DELETE COMMENT

  def delete_comment_button(comment)
    button_element(id: "delete-comment-#{comment.id}-btn")
  end

  def delete_comment(comment)
    alert { wait_for_load_and_click delete_comment_button(comment) }
    comment_el_by_id(comment).when_not_present Utils.short_wait
  end

end
