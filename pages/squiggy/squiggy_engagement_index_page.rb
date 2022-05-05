class SquiggyEngagementIndexPage

  include PageObject
  include Page
  include SquiggyPages
  include Logging

  def load_page(test)
    navigate_to test.course.engagement_index_url
    wait_until(Utils.medium_wait) { title == "#{SquiggyTool::ENGAGEMENT_INDEX.name}" }
    hide_canvas_footer_and_popup
    switch_to_canvas_iframe
  end

  # USER INFO

  span(:user_info_rank, id: 'engagement-userinfo-rank')
  span(:user_info_points, id: 'engagement-userinfo-points')
  div(:user_info_boxplot, id: 'engagement-userinfo-boxplot')

  def wait_for_poller_sync(&blk)
    tries ||= SquiggyUtils.poller_retries
    begin
      return yield
    end
  rescue
    sleep Utils.short_wait
    (tries -= 1).zero? ? fail : retry
  end

  def wait_for_new_user_sync(test, users)
    wait_for_poller_sync do
      load_scores test
      users.each do |u|
        logger.debug "Checking if #{u.full_name} has been added to the course"
        wait_until(1) { visible_names.include? u.full_name }
      end
    end
  end

  def wait_for_removed_user_sync(test, users)
    wait_for_poller_sync do
      load_scores test
      users.each do |u|
        logger.debug "Checking if #{u.full_name} has been removed from the course"
        wait_until(1) { !visible_names.include? u.full_name }
      end
    end
  end

  # LEADERBOARD

  text_field(:search_input, xpath: '//label[text()="Search"]/following-sibling::input')
  div(:users_table, id: 'leaderboard')
  elements(:users_table_row, :row, xpath: '//div[@id="leaderboard"]//tbody/tr')
  link(:sort_by_rank, xpath: '//th[contains(., "Rank")]')
  link(:sort_by_name, xpath: '//th[contains(., "Name")]')
  link(:sort_by_share, xpath: '//th[contains(., "Share")]')
  link(:sort_by_points, xpath: '//th[contains(., "Points")]')
  link(:sort_by_activity, xpath: '//th[contains(., "Last Activity")]')
  elements(:name, :div, class: 'leaderboard-name')

  def users_table_row_xpath
    '//div[@id="leaderboard"]//tbody/tr'
  end

  def rank_els
    cell_elements(xpath: "#{users_table_row_xpath}/td[1]/div")
  end

  def sharing_els
    cell_elements(xpath: "#{users_table_row_xpath}/td[3]/div")
  end

  def points_els
    cell_elements(xpath: "#{users_table_row_xpath}/td[4]/div")
  end

  def last_activity_els
    cell_elements(xpath: "#{users_table_row_xpath}/td[5]")
  end

  def wait_for_scores
    users_table_element.when_visible Utils.medium_wait
  end

  def load_scores(test)
    load_page test
    wait_for_scores
  end

  # USER LEADERBOARD DATA

  def user_row_xpath(user)
    "//tr[contains(., '#{user.full_name}')]"
  end

  def search_for_user(user)
    logger.debug "Searching for #{user.full_name}"
    wait_for_element_and_type(search_input_element, user.full_name)
  end

  def user_score_el(user)
    div_element(xpath: "#{user_row_xpath user}/td[4]/div")
  end

  def user_sharing_el(user)
    div_element(xpath: "#{user_row_xpath user}/td[3]/div")
  end

  def user_score(test, user)
    load_scores test
    search_for_user user
    sleep 1
    user_score_el(user).when_visible Utils.medium_wait
    score = user_score_el(user).text.to_i
    logger.debug "#{user.full_name}'s score is currently '#{score}'"
    score
  end

  def user_score_updated?(test, user, expected_score, retries = nil)
    tries ||= (retries ? retries : SquiggyUtils.poller_retries)
    logger.info("Checking if #{user.full_name} has an updated score of #{expected_score}")
    load_scores test
    wait_until(3) { user_score(test, user) == expected_score }
    user.score = expected_score
    true
  rescue => e
    logger.error "#{e.message}. Score is not yet updated, retrying"
    sleep Utils.short_wait
    retry unless (tries -= 1).zero?
    false
  end

  # SORTING

  def visible_ranks
    rank_els.map(&:text).map &:to_i
  end

  def visible_names
    name_elements.map &:text
  end

  def visible_sharing
    sharing_els.map &:text
  end

  def visible_points
    points_els.map(&:text).map &:to_i
  end

  def visible_activity_dates
    last_activity_els.map { |date| Date.strptime(date.text, '%m/%d/%Y, %l:%M:%S %p') }
  end

  def sorted_asc?(el)
    el.attribute('aria-sort') == 'ascending'
  end

  def sorted_desc?(el)
    el.attribute('aria-sort') == 'descending'
  end

  def sort_asc(sort_el)
    tries = 3
    until sorted_asc?(sort_el) || tries.zero?
      tries -= 1
      sort_el.click
    end
    fail unless sorted_asc? sort_el
  end

  def sort_desc(sort_el)
    tries = 3
    until sorted_desc?(sort_el) || tries.zero?
      tries -= 1
      sort_el.click
    end
    fail unless sorted_desc? sort_el
  end

  def sort_by_rank_asc
    logger.info 'Sorting by "Rank" ascending'
    sort_asc sort_by_rank_element
  end

  def sort_by_rank_desc
    logger.info 'Sorting by "Rank" descending'
    sort_desc sort_by_rank_element
  end

  def sort_by_name_asc
    logger.info 'Sorting by "Name" ascending'
    sort_asc sort_by_name_element
  end

  def sort_by_name_desc
    logger.info 'Sorting by "Name" descending'
    sort_desc sort_by_name_element
  end

  def sort_by_share_asc
    logger.info 'Sorting by "Share" ascending'
    sort_asc sort_by_share_element
  end

  def sort_by_share_desc
    logger.info 'Sorting by "Share" descending'
    sort_desc sort_by_share_element
  end

  def sort_by_points_asc
    logger.info 'Sorting by "Points" ascending'
    sort_asc sort_by_points_element
  end

  def sort_by_points_desc
    logger.info 'Sorting by "Points" descending'
    sort_desc sort_by_points_element
  end

  def sort_by_activity_asc
    logger.info 'Sorting by "Last Activity" ascending'
    sort_asc sort_by_activity_element
  end

  def sort_by_activity_desc
    logger.info 'Sorting by "Last Activity" descending'
    sort_desc sort_by_activity_element
  end

  # SHARING

  checkbox(:share_score_cbx, id: 'share-my-score')
  button(:continue_button, xpath: '//button[contains(., "Continue")]')

  def share_score
    scroll_to_bottom
    share_score_cbx_element.when_present Utils.short_wait
    logger.info 'Sharing score'
    js_click(share_score_cbx_element) unless share_score_cbx_checked?
    continue_button if continue_button?
    wait_for_scores
  end

  def un_share_score
    scroll_to_bottom
    share_score_cbx_element.when_present Utils.short_wait
    logger.info 'Un-sharing score'
    share_score_cbx_checked? ? js_click(share_score_cbx_element) : logger.warn('Score is already un-shared')
    continue_button if continue_button?
  end

  def sharing_preference(user)
    # Retry once to avoid collision with DOM update
    tries = 2
    user_sharing_el(user).text
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    retry unless (tries -= 1).zero?
  end

  # CSV EXPORT

  link(:download_csv_link, id: 'download-csv-btn')

  def download_csv(test)
    logger.info 'Downloading activities CSV'
    Utils.prepare_download_dir
    load_scores test

    # Keep track of the current window since the download can trigger a new one to open
    window = browser.window_handle
    window_count = browser.window_handles.length
    wait_for_update_and_click download_csv_link_element

    csv_file_path = "#{Utils.download_dir}/engagement_index_activities_#{test.course.site_id}_#{Time.now.strftime('%Y-%m-%d')}_*.csv"
    wait_until(Utils.medium_wait) { Dir[csv_file_path].any? }
    csv_file = Dir[csv_file_path].first
    csv = CSV.table csv_file

    new_window_count = browser.window_handles.length
    if new_window_count > window_count
      browser.switch_to.window browser.window_handles.last
      browser.close
    end
    browser.switch_to.window window
    csv
  end

  def csv_activity_row(csv, activity, user, previous_total_score)
    row = csv.find do |r|
      r[:user_name] == user.full_name &&
        r[:action] == activity.type &&
        r[:score] == activity.points &&
        r[:running_total] == (previous_total_score + activity.points)
    end
    previous_total_score += activity.points if row
    row
  end

  # POINTS CONFIG

  # View

  button(:points_config_button, id: 'points-configuration-btn')
  button(:back_to_engagement_index, id: 'back-to-engagement-index-btn')
  elements(:enabled_activity_title, :cell, xpath: '//table[@id="enabled-activities-table"]//td[@class="activity-title"]')
  elements(:disabled_activity_title, :cell, xpath: '//table[@id="disabled-activities-table"]//td[@class="activity-title"]')

  def click_points_config
    wait_for_update_and_click points_config_button_element
    wait_until(Utils.short_wait) { enabled_activity_title_elements.any? }
    sleep 1
  end

  def enabled_activity_titles
    enabled_activity_title_elements.map &:text
  end

  def disabled_activity_titles
    disabled_activity_title_elements.map &:text
  end

  def activity_points(activity)
    cell_element(xpath: "//td[text()=\"#{activity.title}\"]/following-sibling::td").text.to_i
  end

  # Edit

  button(:edit_points_config_button, id: 'edit-btn')
  elements(:activity_edit, :text_field, xpath: '//input[contains(@id, "points-edit-")]')
  button(:cancel_button, id: 'cancel-edit-btn')

  def points_input(activity)
    text_field_element(id: "points-edit-#{activity.type}")
  end

  def disable_activity_button(activity)
    button_element(id: "disable-#{activity.type}")
  end

  def enable_activity_button(activity)
    button_element(id: "enable-#{activity.type}")
  end

  def click_edit_points_config
    logger.info 'Clicking edit points button'
    wait_for_update_and_click edit_points_config_button_element
    wait_until(Utils.short_wait) { activity_edit_elements.any? }
  end

  def click_disable_activity(activity)
    logger.info "Disabling activity type '#{activity.type}'"
    wait_for_update_and_click_js disable_activity_button(activity)
    enable_activity_button(activity).when_visible 2
  end

  def click_enable_activity(activity)
    logger.info "Enabling activity type '#{activity.type}'"
    wait_for_update_and_click_js enable_activity_button(activity)
    disable_activity_button(activity).when_visible 2
  end

  def click_cancel_config_edit
    logger.info 'Canceling config edit'
    wait_for_update_and_click cancel_button_element
  end

  def click_save_config_edit
    logger.info 'Saving config edit'
    wait_for_update_and_click save_button_element
    sleep 1
  end

  def disable_activity(activity)
    click_edit_points_config if edit_points_config_button?
    click_disable_activity activity
    click_save_config_edit
  end

  def enable_activity(activity)
    click_edit_points_config if edit_points_config_button?
    click_enable_activity activity
    click_save_config_edit
  end

  def change_activity_points(activity, new_points)
    logger.info "Changing '#{activity.type}' points from #{activity.points} to #{new_points}"
    click_edit_points_config if edit_points_config_button?
    wait_for_textbox_and_type(points_input(activity), new_points)
    click_save_config_edit
    activity.points = new_points
  end

  def click_back_to_index
    wait_for_update_and_click back_to_engagement_index_element
  end

end
