class SquiggyImpactStudioPage

  include PageObject
  include Logging
  include Page
  include SquiggyPages

  def load_page(url)
    navigate_to url
    wait_until(Utils.medium_wait) { title == "#{SquiggyTool::IMPACT_STUDIO.name}" }
    hide_canvas_footer_and_popup
    switch_to_canvas_iframe
    activity_event_drops_element.when_visible Utils.medium_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
  end

  # IDENTITY

  # TODO image(:avatar, )
  # TODO h1(:name, )
  # TODO div(:profile_desc, )
  # TODO link(:edit_profile_link, )
  # TODO text_area(:edit_profile_input, )
  # TODO span(:char_limit_msg, )
  # TODO button(:update_profile_button, )
  # TODO link(:cancel_edit_profile, )
  # TODO elements(:section, :span, )
  # TODO span(:last_activity, )
  # TODO link(:engagement_index_link, )
  # TODO link(:turn_on_sharing_link, )
  # TODO div(:engagement_index_score, )
  # TODO span(:engagement_index_rank, )
  # TODO span(:engagement_index_rank_ttl, )

  def sections
    section_elements.map &:text
  end

  def click_edit_profile
    wait_for_update_and_click edit_profile_link_element
  end

  def enter_profile_desc(desc)
    wait_for_element_and_type(edit_profile_input_element, desc)
  end

  def cancel_profile_edit
    wait_for_update_and_click cancel_edit_profile_element
  end

  def edit_profile(desc)
    logger.info "Adding user description '#{desc}'"
    click_edit_profile
    enter_profile_desc desc
    wait_for_update_and_click update_profile_button_element
  end

  def click_engagement_index(event = nil)
    wait_for_update_and_click engagement_index_link_element
    add_event(event, EventType::LINK_TO_ENGAGEMENT_INDEX)
  end

  def click_turn_on
    wait_for_update_and_click turn_on_sharing_link_element
  end

  # LOOKING FOR COLLABORATORS

  # TODO label(:collaboration_toggle, )
  # TODO span(:collaboration_status, )
  # TODO button(:collaboration_button, )

  def set_collaboration_true
    logger.info 'Setting "Looking for collaborators" to true'
    collaboration_status_element.when_present Utils.short_wait
    if collaboration_status.include? 'Not'
      wait_for_update_and_click collaboration_toggle_element
      sleep 1
      wait_until(Utils.short_wait) { !collaboration_status.include?('Not') rescue Selenium::WebDriver::Error::StaleElementReferenceError }
    else
      logger.debug('"Looking for collaborators" is already true, doing nothing')
    end
  end

  def set_collaboration_false
    logger.info 'Setting "Looking for collaborators" to false'
    collaboration_status_element.when_present Utils.short_wait
    if collaboration_status.include? 'Not'
      logger.debug('"Looking for collaborators" is already false, doing nothing')
    else
      wait_for_update_and_click collaboration_toggle_element
      sleep 1
      wait_until(Utils.short_wait) { collaboration_status.include?('Not') rescue Selenium::WebDriver::Error::StaleElementReferenceError }
    end
  end

  def click_collaborate_button
    logger.debug 'Clicking "Collaborate" button'
    wait_for_update_and_click collaboration_button_element
  end

  # SEARCH

  # TODO text_area(:search_input, )
  # TODO button(:browse_previous, )
  # TODO button(:browse_next, )

  def search_for_user(user)
    logger.info "Searching for #{user.full_name} UID #{user.uid}"
    tries ||= 2
    begin
      wait_for_load_and_click name_element
      wait_for_element_and_type(search_input_element, user.full_name)
      (option = list_item_element(xpath: "TODO ...//li[contains(.,'#{user.full_name}')]")).when_present Utils.short_wait
      option.click
      wait_until(Utils.medium_wait) { name == user.full_name }
    rescue
      (tries -= 1).zero? ? fail : retry
    end
  end

  def browse_next_user(browsed_user)
    logger.info "Browsing for next user #{browsed_user.full_name}"
    wait_until(Utils.short_wait) { browse_next_element.text == browsed_user.full_name }
    browse_next
    wait_until(Utils.short_wait) { name == browsed_user.full_name }
  end

  def browse_previous_user(browsed_user)
    logger.info "Browsing for previous user #{browsed_user.full_name}"
    wait_until(Utils.short_wait) { browse_previous_element.text == browsed_user.full_name }
    browse_previous
    wait_until(Utils.short_wait) { name == browsed_user.full_name }
  end

  # ACTIVITY

  def init_user_activities
    (SquiggyActivity::ACTIVITIES.map { |a| [a.type.to_sym, { type: a.activity_drop, count: 0 }] }).to_h
  end

  def activities_by_type(user_activities, eligible_activities)
    types = eligible_activities.map { |a| a.type }
    user_activities.select { |k, _| types.include? k.to_s }
  end

  def contrib_activities(user_activities)
    contrib_activities = [
      SquiggyActivity::VIEW_ASSET,
      SquiggyActivity::LIKE,
      SquiggyActivity::COMMENT,
      SquiggyActivity::ADD_DISCUSSION_TOPIC,
      SquiggyActivity::ADD_DISCUSSION_ENTRY,
      SquiggyActivity::ADD_ASSET_TO_LIBRARY,
      SquiggyActivity::EXPORT_WHITEBOARD,
      SquiggyActivity::ADD_ASSET_TO_WHITEBOARD,
      SquiggyActivity::REMIX_WHITEBOARD
    ]
    activities_by_type(user_activities, contrib_activities)
  end

  def impact_activities(user_activities)
    impact_activities = [
      SquiggyActivity::GET_VIEW_ASSET,
      SquiggyActivity::GET_LIKE,
      SquiggyActivity::GET_COMMENT,
      SquiggyActivity::GET_DISCUSSION_REPLY,
      SquiggyActivity::GET_REMIX_WHITEBOARD,
      SquiggyActivity::GET_ADD_ASSET_TO_WHITEBOARD
    ]
    activities_by_type(user_activities, impact_activities)
  end

  # ACTIVITY NETWORK

  # TODO element(:activity_network,

  def init_user_interactions
    {
      views: { exports: 0, imports: 0 },
      likes: { exports: 0, imports: 0 },
      comments: { exports: 0, imports: 0 },
      posts: { exports: 0, imports: 0 },
      pins: { exports: 0, imports: 0 },
      use_assets: { exports: 0, imports: 0 },
      remixes: { exports: 0, imports: 0 },
      co_creations: { exports: 0, imports: 0 }
    }
  end

  def visible_exports(type)
    # TODO cell_element().text.to_i
  end

  def visible_imports(type)
    # TODO cell_element().text.to_i
  end

  def verify_network_interactions(interactions, user)
    logger.debug "Looking for UID #{user.uid} interactions #{interactions}"
    activity_network_element.when_visible Utils.short_wait
    # Pause to let the bubbles settle down
    sleep 2
    # TODO node = div_element()
    driver.action.move_to(node).perform
    sleep Utils.click_wait
    visible_interactions = {
      views: { exports: visible_exports('Views'), imports: visible_imports('Views') },
      likes: { exports: visible_exports('Likes'), imports: visible_imports('Likes') },
      comments: { exports: visible_exports('Comments'), imports: visible_imports('Comments') },
      posts: { exports: visible_exports('Posts'), imports: visible_imports('Posts') },
      pins: { exports: visible_exports('Pins'), imports: visible_imports('Pins') },
      use_assets: { exports: visible_exports('Assets Added'), imports: visible_imports('Assets Added') },
      remixes: { exports: visible_exports('Remixes'), imports: visible_imports('Remixes') },
      co_creations: { exports: visible_exports('Whiteboards Exported'), imports: visible_imports('Whiteboards Exported') }
    }
    begin
      wait_until(1, "Expected #{interactions}, but got #{visible_interactions}") { visible_interactions == interactions }
    ensure
      # Overwrite the expected counts with the actual counts to prevent a failure in one script step from cascading to following dependent steps.
      interactions.merge! visible_interactions unless visible_interactions.nil?
    end
  end

  # EVENT DROPS

  # TODO element(:activity_event_drops, )
  # TODO link(:drop_asset_title, )
  # TODO span(:drop_activity_type, )
  # TODO link(:drop_activity_user, )

  def activity_type_count(labels, index)
    labels[index] && (((type = labels[index]).include? ' (') ? type.split(' ').last.delete('()').to_i : 0)
  end

  def mouseover_event_drop(line_node)
    mouseover(div_element(xpath: "//*[name()='svg']//*[@class='drop-line'][#{line_node}]/*[name()='circle'][last()]"))
  end

  def expected_event_drop_count(activity_count)
    event_drop_counts = {
      engage_contrib: (activity_count[:view_asset][:count] + activity_count[:like][:count]),
      interact_contrib: (activity_count[:comment][:count] + activity_count[:discussion_topic][:count] + activity_count[:discussion_entry][:count]),
      create_contrib: (activity_count[:add_asset][:count] + activity_count[:export_whiteboard][:count] + activity_count[:whiteboard_add_asset][:count] + activity_count[:remix_whiteboard][:count]),
      engage_impact: (activity_count[:get_view_asset][:count] + activity_count[:get_like][:count]),
      interact_impact: (activity_count[:get_comment][:count] + activity_count[:get_discussion_entry_reply][:count] + activity_count[:get_pin_asset][:count]),
      create_impact: (activity_count[:get_remix_whiteboard][:count] + activity_count[:get_whiteboard_add_asset][:count])
    }
    logger.debug "Expected user event drop counts are #{event_drop_counts}"
    event_drop_counts
  end

  def visible_event_drop_count
    # Pause a couple times to allow a complete DOM update
    sleep 2
    activity_event_drops_element.when_visible Utils.short_wait
    sleep 1
    # TODO elements = div_elements()
    labels = elements.map &:text
    event_drop_counts = {
      engage_contrib: activity_type_count(labels, 0),
      interact_contrib: activity_type_count(labels, 1),
      create_contrib: activity_type_count(labels, 2),
      engage_impact: activity_type_count(labels, 3),
      interact_impact: activity_type_count(labels, 4),
      create_impact: activity_type_count(labels, 5)
    }
    logger.debug "Visible user event drop counts are #{event_drop_counts}"
    event_drop_counts
  end

  def wait_for_canvas_event(test, expected_event_count)
    logger.info "Waiting until the Canvas poller updates the activity event counts to #{expected_event_count}"
    tries ||= SquiggyUtils.poller_retries
    begin
      load_page(test.course.impact_studio_url)
      wait_until(3) { visible_event_drop_count == expected_event_count }
    rescue
      if (tries -= 1).zero?
        fail
      else
        sleep Utils.short_wait
        retry
      end
    end
  end

  def verify_latest_event_drop(user, asset, activity, line_node)
    # Pause to let the activity network settle down
    activity_network_element.when_visible Utils.short_wait
    sleep 2
    mouseover_event_drop(line_node)
    # TODO wait_until(Utils.short_wait) { @driver.find_element() }
    unless asset.nil?
      wait_until(Utils.short_wait, "Expected '#{asset.title}' got '#{drop_asset_title_element.text}'") do
        drop_asset_title_element.text == asset.title
      end
    end
    wait_until(Utils.short_wait, "Expected '#{activity.impact_type_drop}' got '#{drop_activity_type}'") do
      drop_activity_type.include? activity.impact_type_drop
    end
    wait_until(Utils.short_wait, "Expected '#{user.full_name}', got '#{drop_activity_user_element.text}'") do
      drop_activity_user_element.text == user.full_name
    end
  end

  # ASSETS

  def swim_lane_asset_ids(link_elements)
    link_elements.map { |link| link.attribute('href').split('?')[1].split('&')[0][4..-1] }
  end

  def max_asset_ids(ids)
    (ids.length > 4) ? ids[0..3] : ids
  end

  def recent_studio_asset_ids(assets)
    max_asset_ids recent_asset_ids(assets)
  end

  def impactful_studio_asset_ids(assets)
    max_asset_ids impactful_asset_ids(assets)
  end

  def add_site(asset)
    wait_for_update_and_click add_site_link_element
    switch_to_canvas_iframe
    enter_and_submit_url asset
    wait_for_asset_and_get_id asset
  end

  def add_file(asset)
    wait_for_update_and_click upload_link_element
    switch_to_canvas_iframe
    enter_and_upload_file asset
    wait_for_asset_and_get_id asset
  end

  def verify_show_more(driver, expected_asset_ids, show_more_element, event, &search_filter_blk)
    if expected_asset_ids.length > 4
      sleep 1
      wait_for_update_and_click show_more_element
      wait_until(Utils.short_wait) { title == 'Asset Library' }
      switch_to_canvas_iframe
      begin
        return yield
      ensure
        go_back_to_impact_studio(driver, event)
      end
    else
      show_more_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
    end
  end

  # USER ASSETS - mine or another user's

  # TODO button(:user_recent_link, )
  # TODO link(:user_assets_show_more_link, )
  # TODO elements(:user_asset_link, :link, )
  # TODO div(:no_user_assets_msg, )

  def click_user_asset_link(asset)
    logger.info "Clicking thumbnail for Asset ID #{asset.id}"
    # TODO wait_for_update_and_click link_element()
    switch_to_canvas_iframe
  end

  def verify_user_recent_assets(assets, user)
    recent_studio_ids = recent_studio_asset_ids assets
    all_recent_ids = recent_asset_ids assets
    logger.info "Verifying that user Recent assets are #{recent_studio_ids} on the Impact Studio and #{all_recent_ids} on the Asset Library"
    if user_recent_link?
      wait_for_update_and_click_js user_recent_link_element
    end
    wait_until(Utils.short_wait, "Expected #{recent_studio_ids}, got #{swim_lane_asset_ids user_asset_link_elements}") do
      sleep 2
      swim_lane_asset_ids(user_asset_link_elements) == recent_studio_ids
    end
    verify_show_more(recent_studio_ids, user_assets_show_more_link_element) do
      wait_until(Utils.short_wait, "Expected #{user.full_name}, got #{uploader_select}") do
        uploader_select == user.full_name
      end
      wait_until(Utils.short_wait, "Expected #{all_recent_ids}, got #{list_view_asset_ids}") do
        list_view_asset_ids == recent_asset_ids(assets)
      end
    end
  end

  # EVERYONE'S ASSETS

  # TODO h3(:everyone_assets_heading, )
  # TODO button(:everyone_recent_link, )
  # TODO div(:no_everyone_assets_msg, )
  # TODO elements(:everyone_asset_link, :link, )
  # TODO link(:everyone_assets_show_more_link, )

  def everyone_assets_pin_element(asset)
    # TODO button_element()
  end

  def verify_all_recent_assets(assets)
    recent_studio_ids = recent_studio_asset_ids assets
    all_recent_ids = recent_asset_ids assets
    logger.info "Verifying that Everyone's Recent assets are #{recent_studio_ids} on the Impact Studio and #{all_recent_ids} on the Asset Library"
    if everyone_recent_link?
      wait_for_update_and_click_js everyone_recent_link_element
    end
    wait_until(Utils.short_wait, "Expected #{recent_studio_ids}, got #{swim_lane_asset_ids everyone_asset_link_elements}") do
      sleep 2
      swim_lane_asset_ids(everyone_asset_link_elements) == recent_studio_ids
      recent_studio_ids.empty? ? no_everyone_assets_msg_element.visible? : !no_everyone_assets_msg_element.exists?
    end
    verify_show_more(all_recent_ids, everyone_assets_show_more_link_element,) do
      wait_until(Utils.short_wait, 'Gave up waiting for advanced search button') do
        advanced_search_button_element.when_visible Utils.short_wait
      end
      wait_until(Utils.short_wait, "Expected '#{all_recent_ids[0..9]}', got #{list_view_asset_ids}") do
        list_view_asset_ids == recent_asset_ids(assets)[0..9]
      end
    end
  end
end
