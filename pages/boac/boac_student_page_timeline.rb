require_relative '../../util/spec_helper'

module BOACStudentPageTimeline

  include PageObject
  include Logging
  include Page
  include BOACPages

  elements(:topic, :list_item, xpath: '//li[contains(@id, "topic")]')

  # Returns the expected format for a collapsed item date
  # @param time [Time]
  # @return [String]
  def expected_item_short_date_format(time)
    (Time.now.strftime('%Y') == time.strftime('%Y')) ? time.strftime('%b %-d') : time.strftime('%b %-d, %Y')
  end

  # Returns the expected format for an expanded item date
  # @param time [Time]
  # @return [String]
  def expected_item_long_date_format(time)
    format = (Time.now.strftime('%Y') == time.strftime('%Y')) ? time.strftime('%b %-d %l:%M%P') : time.strftime('%b %-d, %Y %l:%M%P')
    format.gsub(/\s+/, ' ')
  end

  # Returns the visible sequence of item ids
  # @param item_type [String]
  # @return [Array<String>]
  def visible_collapsed_item_ids(item_type)
    els = div_elements(xpath: "//div[contains(@id, '#{item_type}-') and contains(@id, '-is-closed')]")
    els.map do |el|
      parts = el.attribute('id').split('-')
      (parts[2] == 'is') ? parts[1] : parts[1..2].join('-')
    end
  end

  # Returns the item element visible when the item is collapsed
  # @param item [Object]
  # @return [PageObject::Elements::Div]
  def collapsed_item_el(item)
    type = (item.instance_of?(Note) || item.instance_of?(NoteBatch)) ? 'note' : 'appointment'
    div_element(id: "#{type}-#{item.id}-is-closed")
  end

  # Returns the visible sequence of message ids, whether or not collapsed
  # @return [Array<String>]
  def visible_message_ids
    els = row_elements(xpath: '//tr[contains(@class, "message-row")]')
    ids = els.map { |el| el.attribute('id').split('-')[2..-1].join('-') }
    logger.debug "Visible message IDs are #{ids}"
    ids
  end

  # Returns the button element for collapsing a given item
  # @param item [Object]
  # @return [PageObject::Elements::Button]
  def close_msg_button(item)
    type = (item.instance_of?(Note) || item.instance_of?(NoteBatch)) ? 'note' : 'appointment'
    button_element(xpath: "//tr[@id='permalink-#{type}-#{item.id}']//button[contains(@id, '-close-message')]")
  end

  # Returns the visible item date when the item is collapsed
  # @param item [Object]
  # @return [Hash]
  def visible_collapsed_item_data(item)
    type = (item.instance_of?(Note) || item.instance_of?(NoteBatch)) ? 'note' : 'appointment'
    subject_el = div_element(id: "#{type}-#{item.id}-is-closed")
    date_el = div_element(id: "collapsed-#{type}-#{item.id}-created-at")
    {
        :subject => (subject_el.attribute('innerText').gsub("\n", '') if subject_el.exists?),
        :date => (date_el.text.gsub(/\s+/, ' ') if date_el.exists?)
    }
  end

  # Whether or not a given item is expanded
  # @param item [Object]
  # @return [boolean]
  def item_expanded?(item)
    type = (item.instance_of?(Note) || item.instance_of?(NoteBatch)) ? 'note' : 'appointment'
    div_element(id: "#{type}-#{item.id}-is-open").exists?
  end

  # Expands an item unless it's already expanded
  # @param item [Object]
  def expand_item(item)
    type = (item.instance_of?(Note) || item.instance_of?(NoteBatch)) ? 'note' : 'appointment'
    if item_expanded? item
      logger.debug "#{type.capitalize} ID #{item.id} is already expanded"
    else
      logger.debug "Expanding #{type} ID #{item.id}"
      wait_for_update_and_click_js collapsed_item_el(item)
    end
  end

  # Collapses an item unless it's already collapsed
  # @param item [Object]
  def collapse_item(item)
    type = (item.instance_of?(Note) || item.instance_of?(NoteBatch)) ? 'note' : 'appointment'
    if item_expanded? item
      logger.debug "Collapsing #{type} ID #{item.id}"
      wait_for_update_and_click close_msg_button(item)
    else
      logger.debug "#{type.capitalize} ID #{item.id} is already collapsed"
    end
  end

end
