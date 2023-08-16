class RipleyJobsPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  def run_job_button(job)
    button_element(id: "run-job-#{job.key}")
  end

  def job_most_recent_locator(job)
    "//h2[contains(text(), 'History')]/../../following-sibling::div//tbody/tr[contains(., '#{job.key}')][1]"
  end

  def job_succeeded?(job)
    image_element(xpath: "#{job_most_recent_locator job}//i[contains(@class, 'success')]").exists?
  end

  def job_failed?(job)
    image_element(xpath: "#{job_most_recent_locator job}//i[contains(@class, 'error')]").exists?
  end

  def run_job(job)
    logger.info "Running #{job.name}"
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
