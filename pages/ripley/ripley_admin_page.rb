class RipleyAdminPage

  include PageObject
  include Page
  include RipleyPages
  include Logging

  ## LTI PORTFOLIO ##

  link(:mailing_lists_link, id: 'tool-mailing-lists-manager-link')
  link(:manage_sites_link, id: 'tool-manage-sites-link')
  link(:user_provision_link, id: 'tool-user-provision-link')

  def click_mailing_lists
    logger.info 'Clicking Mailing Lists tool link'
    wait_for_update_and_click mailing_lists_link_element
  end

  def click_manage_sites
    logger.info 'Clicking Manage Sites tool link'
    wait_for_update_and_click manage_sites_link_element
  end

  def click_user_provisioning
    logger.info 'Clicking User Provisioning tool link'
    wait_for_update_and_click user_provision_link_element
  end

  text_field(:site_id_input, id: 'update-canvas-course-id')
  button(:site_id_button, id: 'update-canvas-site-id-btn')

  def enter_site_id(site)
    logger.info "Entering course site ID #{site.site_id}"
    wait_for_textbox_and_type(site_id_input_element, site.site_id)
    wait_for_update_and_click site_id_button_element
  end

  link(:e_grades_link, id: 'tool-e-grade-export-link')
  link(:add_user_link, id: 'tool-find-a-person-to-add-link')
  link(:newt_link, id: 'tool-grade-distribution-link')
  link(:mailing_list_link, id: 'tool-mailing-list-link')
  link(:roster_photos_link, id: 'tool-roster-photos-link')

  def site_link(site)
    link_element(xpath: "//a[@href='#{Utils.canvas_base_url}/courses/#{site.site_id}']")
  end

  ## MU-TH-UR 6000 ##

  def run_job_button(job)
    button_element(id: "run-job-#{job.key}")
  end

  def job_most_recent_locator(job)
    "//h2[contains(., 'Job History')]/../../following-sibling::div//tbody/tr[contains(., '#{job.key}')][1]"
  end

  def job_succeeded?(job)
    image_element(xpath: "#{job_most_recent_locator job}//i[contains(@class, 'success')]").exists?
  end

  def job_failed?(job)
    image_element(xpath: "#{job_most_recent_locator job}//i[contains(@class, 'error')]").exists?
  end

  def run_job(job)
    logger.info "Running #{job.name}"
    sleep 3
    cas_btn = button_element(id: 'cas-auth-submit-button')
    cas_btn.click if cas_btn.exists?
    wait_for_update_and_click run_job_button(job)
    wait_for_job_to_finish job
  end

  def wait_for_job_to_finish(job, retries=nil)
    tries ||= (retries || Utils.medium_wait)
    logger.info "Waiting for #{job.name} to finish"
    wait_until(3) { job_succeeded? job }
  rescue => e
    if (tries -= 1).zero?
      fail e.message
    elsif job_failed? job
      logger.error 'Job failed!'
      fail "#{job.name} failed"
    else
      logger.debug 'Job still running'
      sleep Utils.short_wait
      retry
    end
  end
end
