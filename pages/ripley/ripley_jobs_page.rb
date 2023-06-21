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

  def wait_for_job_to_finish(job, retries=nil)
    tries ||= (retries || Utils.long_wait)
    logger.info "Waiting for #{job.name} to finish"
    wait_until(1) { job_succeeded?(job) || job_failed?(job) }
    if job_succeeded? job
      logger.info 'Job succeeded'
    elsif job_failed? job
      fail 'Job failed!'
    end
  rescue => e
    if (tries -= 1).zero?
      fail e.message
    else
      logger.debug 'Job still running'
      sleep Utils.short_wait
      retry
    end
  end
end
