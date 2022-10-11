class SquiggyImpactStudioPage

  include PageObject
  include Logging
  include Page
  include SquiggyPages

  def load_page(test)
    navigate_to test.course.impact_studio_url
    wait_until(Utils.medium_wait) { title == "#{SquiggyTool::IMPACT_STUDIO.name}" }
    hide_canvas_footer_and_popup
    switch_to_canvas_iframe
  end

  def wait_for_profile(user)
    name_element.when_visible Utils.short_wait
    wait_until(Utils.short_wait) { name == user.full_name }
  end

  def load_own_profile(test, user)
    load_page test
    wait_for_profile user
  end

  # IDENTITY

  image(:avatar, class: 'profile-avatar')
  h1(:name, id: 'profile-header-name')
  div(:profile_desc, xpath: '//div[@id="profile-personal-description"]/div')
  button(:edit_profile_button, id: 'profile-personal-description-edit-btn')
  text_field(:edit_profile_input, id: 'profile-personal-description-input')
  # TODO span(:char_limit_msg, )
  button(:update_profile_button, id: 'confirm-personal-description-btn')
  button(:cancel_edit_profile, id: 'cancel-personal-description-btn')
  div(:section, id: 'canvas-course-sections')
  span(:last_activity, xpath: '//div[@id="profile-last-activity"]/span')

  def sections
    section.strip
  end

  def click_edit_profile
    wait_for_update_and_click edit_profile_button_element
  end

  def enter_profile_desc(desc)
    enter_squiggy_text(edit_profile_input_element, desc)
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

  def click_engagement_index
    wait_for_update_and_click engagement_index_link_element
  end

  def click_turn_on
    wait_for_update_and_click turn_on_sharing_link_element
  end

  # LOOKING FOR COLLABORATORS

  button(:collaboration_button, id: 'toggle-looking-for-collaborators-btn')
  div(:collaboration_status, id: 'profile-looking-for-collaborators')

  def set_collaboration_true
    logger.info 'Setting "Looking for collaborators" to true'
    collaboration_status_element.when_present Utils.short_wait
    if collaboration_status.include? 'Not'
      wait_for_update_and_click collaboration_button_element
      sleep 1
      wait_until(Utils.short_wait) { !collaboration_status.include? 'Not' }
    end
  end

  def set_collaboration_false
    logger.info 'Setting "Looking for collaborators" to false'
    collaboration_status_element.when_present Utils.short_wait
    unless collaboration_status.include? 'Not'
      wait_for_update_and_click collaboration_button_element
      sleep 1
      wait_until(Utils.short_wait) { collaboration_status.include? 'Not' }
    end
  end

  def click_collaborate_button
    logger.debug 'Clicking "Collaborate" button'
    wait_for_update_and_click collaboration_button_element
  end

  # SEARCH

  select_list(:user_select, id: 'find-user-select')
  button(:user_select_button, id: 'find-user-apply')
  link(:browse_previous, xpath: '//div[@id="previous-user"]/a')
  link(:browse_next, xpath: '//div[@id="next-user"]/a')

  def select_user(user)
    logger.info "Selecting #{user.full_name}"
    wait_for_element_and_select_js(user_select_element, user.full_name)
    wait_for_update_and_click_js user_select_button_element
    wait_for_profile user
  end

  def browse_next_user(user)
    logger.info "Browsing next user #{user.full_name}"
    wait_for_load_and_click browse_next_element
    wait_for_profile user
  end

  def browse_previous_user(user)
    logger.info "Browsing previous user #{user.full_name}"
    wait_for_load_and_click browse_previous_element
    wait_for_profile user
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

  element(:activity_network, xpath: '//*[name()="svg"][@id="profile-activity-network"]')

  def init_user_interactions
    {
      views: { exports: 0, imports: 0 },
      likes: { exports: 0, imports: 0 },
      comments: { exports: 0, imports: 0 },
      posts: { exports: 0, imports: 0 },
      use_assets: { exports: 0, imports: 0 },
      remixes: { exports: 0, imports: 0 },
      co_creations: { exports: 0, imports: 0 }
    }
  end

  def visible_trade_row_xpath(type)
    "//table[@class='profile-activity-network-tooltip-table']/tr[contains(., '#{type}')]"
  end

  def visible_exports(type)
    el = cell_element(xpath: "#{visible_trade_row_xpath(type)}/td[2]")
    el.when_present Utils.short_wait
    el.text.to_i
  end

  def visible_imports(type)
    el = cell_element(xpath: "#{visible_trade_row_xpath(type)}/td[5]")
    el.when_present Utils.short_wait
    el.text.to_i
  end

  def get_visible_network_interactions(user)
    activity_network_element.when_visible Utils.short_wait
    sleep 2
    xpath = "//*[name()='svg'][@id='profile-activity-network']//*[name()='g'][@class='nodes']/*[name()='g'][@id='profile-activity-network-user-node-#{user.squiggy_id}']"
    el = element_element(xpath: xpath)
    scroll_to_element el
    @driver.action.move_to(el.selenium_element).perform
    sleep 2
    {
      views: { exports: visible_exports('Views'), imports: visible_imports('Views') },
      likes: { exports: visible_exports('Likes'), imports: visible_imports('Likes') },
      comments: { exports: visible_exports('Comments'), imports: visible_imports('Comments') },
      posts: { exports: visible_exports('Posts'), imports: visible_imports('Posts') },
      use_assets: { exports: visible_exports('Assets Added to Whiteboard'), imports: visible_imports('Assets Added to Whiteboard') },
      remixes: { exports: visible_exports('Remixes'), imports: visible_imports('Remixes') },
      co_creations: { exports: visible_exports('Whiteboards Exported'), imports: visible_imports('Whiteboards Exported') }
    }
  end

  def verify_network_interactions(interactions, target_user)
    logger.info "Looking for UID #{target_user.uid} interactions #{interactions}"
    visible_interactions = get_visible_network_interactions target_user
    begin
      wait_until(1, "Expected #{interactions}, but got #{visible_interactions}") { visible_interactions == interactions }
    ensure
      interactions.merge! visible_interactions unless visible_interactions.nil?
    end
  end

  def wait_for_own_profile_canvas_activity(test, user, interactions, target_user)
    logger.info "Waiting until the Canvas poller updates the activity network trade figures to #{interactions}"
    tries ||= SquiggyUtils.poller_retries
    begin
      load_own_profile(test, user)
      visible_interactions = get_visible_network_interactions target_user
      wait_until(1, "Expected #{interactions}, but got #{visible_interactions}") { visible_interactions == interactions }
    rescue
      if (tries -= 1).zero?
        fail
      else
        logger.info 'Retrying'
        sleep Utils.short_wait
        retry
      end
    ensure
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

  def assets_visible_non_deleted(assets)
    assets.select(&:visible).reject(&:deleted)
  end

  def assets_most_recent(assets)
    assets_visible_non_deleted(assets).sort_by(&:id).reverse[0..3]
  end

  def assets_most_viewed(assets)
    assets_visible_non_deleted(assets).reject { |a| a.count_views.zero? }.sort_by { |a| [a.count_views, a.id] }.reverse[0..3]
  end

  def assets_most_liked(assets)
    assets_visible_non_deleted(assets).reject { |a| a.count_likes.zero? }.sort_by { |a| [a.count_likes, a.id] }.reverse[0..3]
  end

  def assets_most_commented(assets)
    assets_visible_non_deleted(assets).reject { |a| a.comments.length.zero? }.sort_by { |a| [a.comments.length, a.id] }.reverse[0..3]
  end

  # USER ASSETS

  select_list(:sort_user_assets_select, id: 'user-assets-sort-select')
  button(:sort_user_assets_apply_button, id: 'user-assets-sort-apply')
  elements(:user_asset, :div, xpath: '//div[@id="user-assets"]//div[starts-with(@id, "asset-")]')
  div(:no_user_assets_msg, id: 'user-assets-no-assets-msg')
  link(:user_assets_show_more_link, id: 'user-assets-view-all-link')

  def sort_user_assets(option)
    logger.info "Sorting user assets by #{option}"
    scroll_to_bottom
    wait_for_element_and_select_js(sort_user_assets_select_element, option)
    wait_for_update_and_click_js sort_user_assets_apply_button_element
  end

  def user_asset_xpath(asset)
    "//div[@id='user-assets']//div[@id='asset-#{asset.id}']"
  end

  def user_asset_ids
    user_asset_elements.map { |el| el.attribute('id').split('-').last }
  end

  def user_asset_el(asset)
    div_element(xpath: user_asset_xpath(asset))
  end

  def click_user_asset_link(asset)
    logger.info "Clicking thumbnail for Asset ID #{asset.id} #{asset.title}"
    scroll_to_bottom
    wait_for_update_and_click user_asset_el(asset)
  end

  def wait_for_user_asset_results(assets)
    sleep 1
    expected = assets.map &:id
    wait_until(Utils.short_wait, "Expected #{expected}, got #{user_asset_ids}") { user_asset_ids == expected }
  end

  def wait_for_no_user_asset_results
    no_user_assets_msg_element.when_visible Utils.short_wait
  end

  # EVERYONE'S ASSETS

  h2(:everyone_assets_heading, xpath: '//h2[text()="Everyone\'s Assets"]')
  select_list(:sort_everyone_assets_select, id: 'everyones-assets-sort-select')
  button(:sort_everyone_assets_apply_button, id: 'everyones-assets-sort-apply')
  elements(:everyone_asset, :div, xpath: '//div[@id="everyones-assets"]//div[starts-with(@id, "asset-")]')
  div(:no_everyone_assets_msg, id: 'everyones-assets-no-assets-msg')
  link(:everyone_assets_show_more_link, id: 'everyones-assets-view-all-link')

  def sort_everyone_assets(option)
    logger.info "Sorting everyone's assets by #{option}"
    scroll_to_bottom
    wait_for_element_and_select_js(sort_everyone_assets_select_element, option)
    wait_for_update_and_click_js sort_everyone_assets_apply_button_element
  end

  def everyone_asset_xpath(asset)
    "//div[@id='everyones-assets']//div[@id='asset-#{asset.id}']"
  end

  def everyone_asset_ids
    everyone_asset_elements.map { |el| el.attribute('id').split('-').last }
  end

  def everyone_asset_el(asset)
    div_element(xpath: everyone_asset_xpath(asset))
  end

  def click_everyone_asset_link(asset)
    logger.info "Clicking thumbnail for Asset ID #{asset.id}"
    wait_for_update_and_click everyone_asset_el(asset)
  end

  def wait_for_everyone_asset_results(assets)
    sleep 1
    expected = assets.map &:id
    wait_until(Utils.short_wait, "Expected #{expected}, got #{everyone_asset_ids}") { everyone_asset_ids == expected }
  end

  def wait_for_no_everyone_asset_results
    no_everyone_assets_msg_element.when_visible Utils.short_wait
  end
end
