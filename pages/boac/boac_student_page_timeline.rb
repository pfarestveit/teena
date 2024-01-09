require_relative '../../util/spec_helper'

module BOACStudentPageTimeline

  include PageObject
  include Logging
  include Page
  include BOACPages

  elements(:topic, :list_item, xpath: '//li[contains(@id, "topic")]')

  def item_type(item)
    if item.instance_of?(Note) || item.instance_of?(NoteBatch)
      'note'
    elsif item.instance_of? TimelineEForm
      'eForm'
    else
      'appointment'
    end
  end

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
      (parts[2] == 'is') ? parts[1] : parts[1..-3].join('-')
    end
  end

  # Returns the item element visible when the item is collapsed
  # @param item [Object]
  # @return [Element]
  def collapsed_item_el(item)
    type = item_type item
    logger.debug "Searching for collapsed item element for #{type}"
    if @driver.browser.to_s == 'firefox'
      row_element(xpath: "//tr[@id='permalink-#{type}-#{item.id}']/td")
    else
      row_element(id: "permalink-#{type}-#{item.id}")
    end
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
  # @return [Element]
  def close_msg_button(item)
    button_element(xpath: "//tr[@id='permalink-#{item_type item}-#{item.id}']//button[contains(@id, '-close-message')]")
  end

  # Returns the visible item date when the item is collapsed
  # @param item [Object]
  # @return [Hash]
  def visible_collapsed_item_data(item)
    type = item_type item
    div_element(id: "collapsed-#{type}-#{item.id}-created-at").when_visible Utils.short_wait
    subject_el = div_element(id: "#{type}-#{item.id}-is-closed")
    date_el = div_element(id: "collapsed-#{type}-#{item.id}-created-at")
    {
        :subject => (subject_el.text.gsub("\n", '') if subject_el.exists?),
        :date => (date_el.text.gsub(/\s+/, ' ') if date_el.exists?)
    }
  end

  # Whether or not a given item is expanded
  # @param item [Object]
  # @return [boolean]
  def item_expanded?(item)
    div_element(id: "#{item_type item}-#{item.id}-is-open").exists?
  end

  # Expands an item unless it's already expanded
  # @param item [Object]
  def expand_item(item)
    type = item_type item
    if item_expanded? item
      logger.debug "#{type.capitalize} ID #{item.id} is already expanded"
    else
      logger.debug "Expanding #{type} ID #{item.id}"
      wait_for_update_and_click collapsed_item_el(item)
    end
  end

  # Collapses an item unless it's already collapsed
  # @param item [Object]
  def collapse_item(item)
    type = item_type item
    if item_expanded? item
      logger.debug "Collapsing #{type} ID #{item.id}"
      wait_for_update_and_click close_msg_button(item)
    else
      logger.debug "#{type.capitalize} ID #{item.id} is already collapsed"
    end
  end

  # Returns the element containing a given attachment name
  # @param item [Object]
  # @param attachment_name [String]
  # @return [Element]
  def item_attachment_el(item, attachment_name)
    item_attachment_els(item).find { |el| el.text.strip == attachment_name }
  end

  # Returns the elements containing both downloadable and non-downloadable attachments
  # @param item [Object]
  # @return [Array<Element>]
  def item_attachment_els(item)
    type = item_type item
    spans = span_elements(xpath: "//li[contains(@id, '#{type}-#{item.id}-attachment')]//span[contains(@id, '-attachment-')]")
    links = link_elements(xpath: "//li[contains(@id, '#{type}-#{item.id}-attachment')]//a[contains(@id, '-attachment-')]")
    spans + links
  end

  # Downloads an attachment and returns the file size, deleting the file once downloaded. If the download is not available,
  # logs a warning and moves on if a SIS note or logs and error and fails if a Boa note.
  # @param record [TimelineRecord]
  # @param attachment [Attachment]
  # @param student [BOACUser]
  # @return [Integer]
  def download_attachment(record, attachment, student=nil)
    logger.info "Downloading attachment '#{attachment.id || attachment.sis_file_name}' from record ID #{record.id}"
    Utils.prepare_download_dir
    if record.instance_of? Note
      wait_until(Utils.short_wait) { item_attachment_els(record).any? }
      hide_boac_footer
      item_attachment_el(record, attachment.file_name).click
    else
      wait_until(Utils.short_wait) { item_attachment_els(record).any? }
      hide_boac_footer
      item_attachment_el(record, attachment.file_name).click
    end
    file_path = "#{Utils.download_dir}/#{attachment.file_name}"
    wait_until(Utils.medium_wait) { sorry_no_attachment_msg? || Dir[file_path].any?  }

    if sorry_no_attachment_msg?
      # Get back on the student page for subsequent tests
      load_page student
      record.instance_of?(Note) ? show_notes : show_appts

      if attachment.sis_file_name
        logger.warn "Cannot download SIS note ID #{record.id} attachment ID '#{attachment.sis_file_name}'"
      else
        logger.error "Cannot download Boa note ID #{record.id} attachment ID '#{attachment.id}'"
      end
      fail
    else
      file = File.new file_path

      # If the attachment file size is known (i.e., it was uploaded as part of the test), then make sure the download reaches the same size.
      if attachment.file_size
        wait_until(Utils.medium_wait) do
          logger.debug "File size is currently #{file.size}, waiting until it reaches #{attachment.file_size}"
          file.size == attachment.file_size
        end
      end
      size = file.size

      # Zap the download dir again to make sure no attachment downloads are left behind on the test machine
      Utils.prepare_download_dir
      size
    end
  end

end
