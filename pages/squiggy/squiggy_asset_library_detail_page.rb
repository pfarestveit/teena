class SquiggyAssetLibraryDetailPage < SquiggyAssetLibraryListViewPage

  include PageObject
  include Page
  include Logging
  include SquiggyAssetLibraryMetadataForm
  include SquiggyWhiteboardEditForm

  h2(:asset_title, id: 'page-title')
  span(:uh_oh, xpath: '//span[text()=" Uh oh! "]')
  div(:asset_preview, id: 'asset-preview')
  button(:like_button, id: 'like-asset-btn')
  span(:like_count, id: 'asset-like-count')
  span(:view_count, id: 'asset-view-count')
  span(:comment_count, id: 'asset-comment-count')
  div(:description, id: 'asset-description')
  div(:source, xpath: '//div[contains(text(), "Source:")]')

  def hit_asset_detail(test, asset)
    navigate_to 'https://www.google.com'
    text_area_element(name: 'q').when_present Utils.short_wait
    sleep 2
    logger.info "Hitting asset detail at '#{test.course_site.asset_library_url}#suitec_assetId=#{asset.id}'"
    navigate_to "#{test.course_site.asset_library_url}#suitec_assetId=#{asset.id}"
    switch_to_canvas_iframe
  end

  def load_asset_detail(test, asset)
    hit_asset_detail(test, asset)
    wait_for_asset_detail
  end

  def hit_unavailable_asset(test, asset)
    hit_asset_detail(test, asset)
    uh_oh_element.when_visible Utils.short_wait
  end

  def wait_for_asset_detail
    wait_for_element(asset_title_element, Utils.short_wait)
    sleep 1
  end

  def wait_for_asset_and_get_id(asset)
    wait_for_element(asset_title_element, Utils.medium_wait)
    asset.id = SquiggyUtils.set_asset_id asset
  end

  def owner_el(asset)
    link_element(xpath: "//a[contains(text(), '#{asset.owner.full_name}')]")
  end

  def category_el_by_text(asset)
    logger.debug "Looking for element at XPath //a[contains(text(), #{asset.category.name})]"
    link_element(xpath: "//a[contains(text(), #{asset.category.name})]")
  end

  def source_el(asset)
    link_element(text: asset.url)
  end

  def category_el_by_id(category)
    link_element(id: "link-to-assets-of-category-#{category.id}")
  end

  def click_category_link(category)
    logger.info "Clicking link to category '#{category.name}'"
    scroll_to_bottom
    wait_for_update_and_click category_el_by_id(category)
  end

  def no_category_el
    div_element(xpath: '//div[text()=" Categories: "]/following-sibling::div/div[text()=" — "]')
  end

  def visible_asset_metadata(asset)
    wait_for_element(asset_title_element, Utils.short_wait)
    owner_el(asset).when_visible Utils.short_wait
    expected_cat = if asset.category
                     category_el_by_id(asset.category).text.strip if category_el_by_id(asset.category).exists?
                   else
                     no_category_el.exists?
                   end
    {
      title: asset_title,
      owner: owner_el(asset).text.strip,
      like_count: (like_count if like_count?),
      view_count: (view_count if view_count?),
      comment_count: (comment_count if comment_count?),
      description: (description.strip if description?),
      source: source_el(asset),
      source_exists: source?,
      category: expected_cat
    }
  end

  # PREVIEW

  button(:regenerate_preview_button, id: 'refresh-asset-preview-btn')
  div(:preparing_preview_msg, xpath: '//div[contains(text(), "Preparing a preview")]')

  def preview_generated?(asset)
    logger.info "Verifying a preview of type '#{asset.preview_type}' is generated for the asset within #{Utils.medium_wait} seconds"
    verify_block do
      if preparing_preview_msg?
        start = Time.now
        logger.debug 'Waiting for preparing preview to go away'
        wait_until(Utils.medium_wait) { !preparing_preview_msg? }
        logger.debug "PERF - Preview prepared in #{Time.now - start} seconds"
      else
        logger.debug 'Preview spinner not present'
      end
      preview_xpath = "//div[@class='preview']"
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
        end).when_present 3
    end
  end

  def click_regenerate_preview
    logger.info 'Clicking the regenerate preview button'
    wait_for_update_and_click regenerate_preview_button_element
  end

  # EDIT DETAILS

  button(:edit_details_button, id: 'edit-asset-details-btn')
  button(:save_asset_edit_button, id: 'confirm-save-asset-btn')
  button(:cancel_asset_edit_button, id: 'cancel-save-asset-btn')

  def click_cancel_button
    wait_for_update_and_click cancel_asset_edit_button_element
  end

  def click_save_button
    wait_for_update_and_click save_asset_edit_button_element
  end

  def edit_asset_details(asset)
    wait_for_update_and_click edit_details_button_element
    enter_asset_metadata asset
    click_save_button
  end

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

  def delete_asset(asset = nil)
    logger.info "Deleting asset#{(' ID ' + asset.id) if asset}"
    wait_for_update_and_click delete_button_element
    wait_for_update_and_click confirm_delete_button_element
    delete_button_element.when_not_present Utils.short_wait
    asset.deleted = true if asset
  end

  # LIKE

  button(:like_button, id: 'like-asset-btn')

  def click_like_button
    logger.info 'Clicking the like button'
    scroll_to_bottom
    wait_for_update_and_click like_button_element
    sleep Utils.click_wait
  end

  # ADD COMMENT

  text_area(:comment_input, id: 'comment-body-textarea')
  button(:comment_add_button, id: 'create-comment-btn')

  def comment_el_by_id(comment)
    div_element(id: "comment-#{comment.id}")
  end

  def comment_el_by_body(comment)
    div_element(xpath: "//div[contains(., '#{comment.body.split.first}') and contains(@id, 'comment')][not(contains(@id, 'body'))]")
  end

  def comment_body_el(comment)
    div_element(id: "comment-#{comment.id}-body")
  end

  def add_comment(comment)
    logger.info "Adding the comment '#{comment.body}'"
    scroll_to_bottom
    enter_squiggy_text(comment_input_element, comment.body)
    wait_until(Utils.short_wait) { comment_add_button_element.enabled? }
    scroll_to_bottom
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
    link_element(xpath: "//div[@id='comment-#{comment.id}-user-name']//a")
  end

  def click_commenter_link(comment)
    logger.info "Clicking the link for comment #{comment.id} #{comment.user.full_name}"
    wait_for_update_and_click commenter_link(comment)
  end

  # REPLY TO COMMENT

  def reply_button_el(comment)
    button_element(id: "reply-to-comment-#{comment.id}-btn")
  rescue Selenium::WebDriver::Error::NoSuchElementError
    nil
  end

  def click_reply_button(comment)
    wait_for_update_and_click reply_button_el(comment)
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
    scroll_to_bottom
    click_reply_button comment
    scroll_to_bottom
    enter_squiggy_text(reply_input_el(comment), reply_comment.body)
    wait_for_update_and_click reply_save_button
    comment_el_by_body(reply_comment).when_visible Utils.short_wait
    reply_comment.set_comment_id
    visible_comment reply_comment
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
    wait_for_update_and_click edit_button(comment)
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
    scroll_to_bottom
    click_edit_button comment
    enter_squiggy_text(edit_comment_text_area(comment), comment.body)
    wait_for_update_and_click save_edit_button
    comment_el_by_body(comment).when_visible Utils.short_wait
  end

  # DELETE COMMENT

  def delete_comment_button(comment)
    logger.debug "Looking for comment delete button at delete-comment-#{comment.id}-btn"
    button_element(id: "delete-comment-#{comment.id}-btn")
  end

  def delete_comment(comment)
    scroll_to_bottom
    wait_for_update_and_click delete_comment_button(comment)
    wait_for_update_and_click confirm_delete_button_element
    comment_el_by_id(comment).when_not_present Utils.short_wait
  end

  # REMIX

  button(:remix_button, id: 'remix-asset-whiteboard-btn')
  link(:remixed_board_link, id: 'link-to-whiteboard')
  h2(:remixed_board_title, id: 'whiteboard-title')
  button(:remix_save_button, id: 'remix-btn')

  def remix(title)
    wait_for_update_and_click remix_button_element
    enter_whiteboard_title title
    wait_for_update_and_click remix_save_button_element
    SquiggyWhiteboard.new id: get_whiteboard_id(remixed_board_link_element), title: remixed_board_title
  end

  def open_remixed_board(whiteboard)
    wait_for_update_and_click remixed_board_link_element
    shift_to_whiteboard_window whiteboard
  end

  # WHITEBOARDS

  elements(:used_in_link, :link, xpath: '//a[contains(@id, "asset-used-in-")]')

  def detail_view_whiteboards_list
    used_in_link_elements.map { |el| el.text.strip }
  end

  def click_whiteboard_usage_link(whiteboard, asset)
    wait_for_update_and_click link_element(id: "asset-used-in-#{asset.id}")
    wait_for_asset_detail
    wait_until(Utils.short_wait) { asset_title == whiteboard.title }
  end

end
