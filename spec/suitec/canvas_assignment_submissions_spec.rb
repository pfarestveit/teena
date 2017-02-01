require_relative '../../util/spec_helper'

include Logging

describe 'Canvas assignment submission', order: :defined do

  begin

    course_id = ENV['course_id']
    test_id = Utils.get_test_id
    @course = Course.new({})
    @course.site_id = course_id

    # Load test data
    user_test_data = Utils.load_test_users.select { |data| data['tests']['canvasAssignmentSubmissions'] }
    users = user_test_data.map { |user_data| User.new(user_data) }
    students = users.select { |user| user.role == 'Student' }
    @teacher = users.find { |user| user.role == 'Teacher' }

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    # Create course site if necessary. If an existing site, then ensure Canvas sync is enabled.
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.get_suite_c_test_course(@course, users, test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX])
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)
    @asset_library.ensure_canvas_sync(@driver, @asset_library_url) unless course_id.nil?

    # Create assignment
    @assignment = Assignment.new("Submission Assignment #{test_id}", nil)
    @canvas.masquerade_as(@teacher, @course)
    @canvas.create_assignment(@course, @assignment)

    # Enable Canvas assignment sync
    @asset_library.wait_for_canvas_category(@driver, @asset_library_url, @assignment)
    @asset_library.enable_assignment_sync @assignment
    @asset_library.pause_for_poller
    @canvas.stop_masquerading

    # Submit assignment
    submissions = []
    students.each do |student|
      begin
        name = student.full_name
        @asset = Asset.new student.assets.first

        # Get user's score before submission
        @engagement_index.load_scores(@driver, @engagement_index_url)
        @initial_score = @engagement_index.user_score student
        logger.debug "The initial score for #{student.full_name} is #{@initial_score}"

        # Submit assignment
        @canvas.masquerade_as(student, @course)
        @canvas.submit_assignment(@assignment, student, @asset)
        @canvas.stop_masquerading

        @asset.title = @asset_library.get_canvas_submission_title @asset
        asset_title = @asset.title
        submissions << [student, @asset, @initial_score]

      rescue => e
        logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
        it("failed for #{name}'s submission '#{asset_title}'") { fail }
      end
    end

    # Verify assignment processed successfully in Asset Library and Engagement Index
    submissions.each do |submission|
      begin
        student = submission[0]
        student_full_name = student.full_name
        asset = submission[1]
        asset_title = asset.title
        asset.description = nil
        asset.category = @assignment.title

        # Check for updated Engagement Index score once submission is processed
        initial_score = submission[2]
        expected_score = initial_score.to_i + Activities::SUBMIT_ASSIGNMENT.points
        logger.debug "Checking submission for #{student_full_name} who uploaded #{asset_title} and should now have a score of #{expected_score}"

        score_updated = @engagement_index.user_score_updated?(@driver, @engagement_index_url, student, "#{expected_score}")

        it("earns 'Submit an Assignment' points on the Engagement Index for #{student_full_name}") { expect(score_updated).to be true }

        # Check that activity is included in CSV download
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
        expected_row = "#{student_full_name}, submit_assignment, #{Activities::SUBMIT_ASSIGNMENT.points}, #{expected_score}"

        it("shows 'submit_assignment' activity on the CSV export for #{student_full_name}") { expect(scores).to include(expected_row) }

        # Check that submission is added to Asset Library with right metadata
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.advanced_search(nil, asset.category, student, asset.type)
        @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_elements.length == 1 }

        file_uploaded = @asset_library.verify_block { @asset_library.verify_first_asset(student, asset) }
        preview_generated = @asset_library.preview_generated?(@driver, @asset_library_url, asset)

        it("appears in the Asset Library for #{student_full_name}") { expect(file_uploaded).to be true }
        it("generate the expected asset preview for #{student_full_name} uploading #{asset_title}") { expect(preview_generated).to be true }

        if asset.type == 'File'
          asset_downloadable = @asset_library.verify_block { @asset_library.download_asset @asset }
          it("can be downloaded by #{student_full_name} from the #{asset_title} asset detail page") { expect(asset_downloadable).to be true }
        else
          has_download_button = @asset_library.download_asset_link?
          it("cannot be downloaded by #{student_full_name} from the #{asset_title} detail page") { expect(has_download_button).to be false }
        end

      rescue => e
        logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
        it("caused an unexpected error checking #{student_full_name}'s submission in SuiteC") { fail }
      end
    end

  rescue => e
    # Catch and report errors related to the whole test
    logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
    it('caused an unexpected error handling the UI') { fail }
  ensure
    @driver.quit
  end

end
