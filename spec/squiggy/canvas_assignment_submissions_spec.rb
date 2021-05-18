require_relative '../../util/spec_helper'

describe 'Canvas assignment submissions' do

  include Logging

  begin

    @test = SquiggyTestConfig.new 'canvas_submissions'
    @test.course.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser
    @canvas = Page::CanvasAssignmentsPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @assignment = Assignment.new title: "#{@test.course.title} Assignment #{@test.id}"
    @canvas.masquerade_as(@test.teachers.first, @test.course)
    @canvas.create_assignment(@test.course, @assignment)

    # Enable Canvas assignment sync
    @manage_assets.wait_for_canvas_category(@test, @assignment)
    @manage_assets.enable_assignment_sync @assignment
    @canvas.stop_masquerading

    submissions = []

    @test.students.each do |student|
      begin
        asset = student.assets.first
        asset.title = @assets_list.canvas_submission_title asset
        asset.owner = student
        student.score = @engagement_index.user_score(@test, student)

        @canvas.masquerade_as(student, @test.course)
        @canvas.submit_assignment(@assignment, student, asset)
        @canvas.stop_masquerading
        submissions << asset
      rescue => e
        it("tests hit an error with student UID #{student.uid}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
      end
    end

    submissions.each do |asset|
      begin
        asset.description = nil
        asset.category = @assignment.title
        type = asset.file_name ? 'File' : 'Link'

        # Activity points
        expected_score = asset.owner.score + SquiggyActivity::SUBMIT_ASSIGNMENT.points
        logger.debug "Checking submission for #{asset.owner.full_name} who uploaded #{asset.title} and should now have a score of #{expected_score}"
        score_updated = @engagement_index.user_score_updated?(@test, asset.owner, expected_score)
        it("earns 'Submit an Assignment' points on the Engagement Index for #{asset.owner.full_name}") do
          expect(score_updated).to be true
        end

        # Check that submission is added to Asset Library with right metadata
        @assets_list.load_page @test
        SquiggyUtils.set_asset_id(asset, @assignment.id)
        @assets_list.advanced_search(nil, asset.category, asset.owner, type, nil)
        visible_asset = @assets_list.visible_list_view_asset_data asset

        it "#{asset.title} belonging to #{asset.owner.full_name} has the right list view title" do
          expect(visible_asset[:title]).to eql(asset.title)
        end
        it "#{asset.title} belonging to #{asset.owner.full_name} has the right list view owner" do
          expect(visible_asset[:owner]).to eql(asset.owner.full_name)
        end

        @assets_list.click_asset_link asset
        visible_detail = @asset_detail.visible_asset_metadata asset
        source_shown = @asset_detail.source_el(asset).exists?
        category_shown = @asset_detail.category_el(asset).exists?
        preview_generated = @asset_detail.preview_generated? asset

        it "#{asset.title} belonging to #{asset.owner.full_name} has the right detail view title" do
          expect(visible_detail[:title]).to eql(asset.title)
        end
        it "#{asset.title} belonging to #{asset.owner.full_name} has the right detail view owner" do
          expect(visible_detail[:owner]).to eql(asset.owner.full_name)
        end
        it "#{asset.title} belonging to #{asset.owner.full_name} has the right detail view description" do
          expect(visible_detail[:description]).to eql(asset.description.to_s)
        end
        it "#{asset.title} belonging to #{asset.owner.full_name} has the right detail view preview type" do
          expect(preview_generated).to be true
        end
        it "#{asset.title} belonging to #{asset.owner.full_name} has the right detail view category" do
          expect(category_shown).to be true
        end
        it "#{asset.title} belonging to #{asset.owner.full_name} has the right detail view source" do
          expect(source_shown).to be true
        end

        if asset.file_name
          asset_downloadable = @asset_detail.verify_block { @asset_detail.download_asset asset }
          it("can be downloaded by #{asset.owner.full_name} from the #{asset.title} asset detail page") do
            expect(asset_downloadable).to be true
          end
        else
          has_download_button = @asset_detail.download_button?
          it("cannot be downloaded by #{asset.owner.full_name} from the #{asset.title} detail page") do
            expect(has_download_button).to be false
          end
        end

      rescue => e
        it "tests hit an error with submission #{asset.inspect}" do
          fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
        end
      end
    end

  rescue => e
        it('tests hit an error initializing') do
          fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
        end
  ensure
    Utils.quit_browser @driver
  end
end
