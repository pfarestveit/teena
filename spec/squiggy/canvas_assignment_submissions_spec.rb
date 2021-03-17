require_relative '../../util/spec_helper'

describe 'Canvas assignment submissions' do

  begin

    @test = SquiggyTestConfig.new 'canvas_submissions'

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test

    @assignment = Assignment.new title: "#{@test.course.title} Assignment"
    @canvas.masquerade_as(@test.teachers.first, @test.course)
    @canvas.create_assignment(@test.course, @assignment)

    submissions = []

    @test.students.each do |student|
      begin
        # TODO Upload asset for assignment and add to submissions
      rescue => e
        it("tests hit an error with student UID #{student.uid}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
      end
    end

    submissions.each do |asset|
      begin
        it 'earn \'Submit an Assignment\' points on the Engagement Index'
        it 'appear in Asset Library search results'
        it 'appear in the Asset Library list view with the right title'
        it 'appear in the Asset Library list view with the right owner'
        it 'appear in the Asset Library detail view with the right title'
        it 'appear in the Asset Library detail view with the right owner'
        it 'appear in the Asset Library detail view with the right description'
        it 'appear in the Asset Library detail view with the right categories'
        it 'appear in the Asset Library detail view with the right source'
        it 'appear in the Asset Library detail view with the right preview type'
        it 'can be downloaded from the Asset Library detail view' if asset.file
        it 'cannot be downloaded from the Asset Library detail view' if asset.url

      rescue => e
        it("tests hit an error with submission #{asset.inspect}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
      end
    end

  rescue => e
        it('tests hit an error initializing') { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
  ensure
    Utils.quit_browser @driver
  end
end
