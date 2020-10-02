require_relative '../../util/spec_helper'

describe 'Junction background tasks' do

  standalone = ENV['STANDALONE']

  begin

    include Logging

    config = JunctionTestConfig.new
    config.background_jobs_load_test
    courses = config.courses.dup * JunctionUtils.background_job_multiplier
    @driver = Utils.launch_browser

    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
    @site_creation_page = Page::JunctionPages::CanvasSiteCreationPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @canvas_page = Page::CanvasPage.new @driver

    # Log in to both Canvas and Junction
    if standalone
      @canvas_page.log_in(@cal_net_page, Utils.ets_qa_username, Utils.ets_qa_password)
    else
      @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password)
    end
    @splash_page.basic_auth config.admin.uid

    tests = courses.map do |course|

      begin

        # Open a separate browser tab for each of the test courses
        window = config.courses.index(course).zero? ? @driver.window_handle : @canvas_page.open_new_window
        test = {
          :course => course,
          :teacher => config.set_sis_teacher(course),
          :sections => config.set_course_sections(course),
          :window => window
        }

        test[:course].create_site_workflow = 'ccn'
        logger.info "Creating a course site for #{test[:course].term} #{test[:course].code} in window ID #{test[:window]}"

        # Kick off a site creation job in Junction
        @create_course_site_page.load_standalone_tool
        @create_course_site_page.switch_mode_element.when_visible Utils.medium_wait
        @create_course_site_page.search_for_course(test[:course], test[:teacher], test[:sections])
        @create_course_site_page.expand_available_sections test[:course].code
        @create_course_site_page.select_sections test[:sections]
        @create_course_site_page.click_next
        @create_course_site_page.enter_site_titles test[:course]
        @create_course_site_page.click_create_site
        test.merge!({:start_time => Time.now})
        test

      # If an error occurs before the job is kicked off, report the error
      rescue => e
        Utils.log_error e
        it("hit an error with #{test[:course].term} #{test[:course].code}") { fail }
        nil
      end
    end

    # Exclude courses that hit errors while kicking off the site creation job
    tests.compact!

    # Poll each window for finished jobs
    tries = JunctionUtils.background_job_attempts
    begin

      # Check each window to see if the site has been created and the redirect to Canvas has occurred
      tests.reject { |t| t[:course].site_id }.each do |test|

        @driver.switch_to.window test[:window]
        logger.info "Checking #{test[:course].term} #{test[:course].code}"
        sleep 1

        if @canvas_page.current_url.include? "#{Utils.canvas_base_url}/courses"
          test[:course].site_id = @canvas_page.current_url.delete "#{Utils.canvas_base_url}/courses/"
          test.merge!({:end_time => Time.now})
          logger.info "#{test[:course].term} #{test[:course].code} site ID #{test[:course].site_id} created within #{test[:end_time] - test[:start_time]} seconds"

        else
          sleep 1
        end
      end

      # If any are still not created, fail and retry them
      (tests.reject { |t| t[:course].site_id }.any?) ? fail : logger.info('All sites have been created')
    rescue
      retry unless (tries -= 1).zero?
    end

    # After retries are exhausted, report successes and failures
    tests.each do |test|
      it("succeeded for #{test[:course].term} #{test[:course].code}") { expect(test[:course].site_id).not_to be_nil }
    end

  rescue => e
    Utils.log_error e
    it('hit an error initializing') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
