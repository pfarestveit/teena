require_relative '../../util/spec_helper'

describe 'New assets' do

  begin

    @test = SquiggyTestConfig.new 'asset_creation'
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test

    @canvas.masquerade_as(@test.course.teachers.first, @test.course)

    @test.students.each do |student|
      begin
        student.assets.each do |asset|
          begin

            if asset.file_name && asset.size > 10
              it "do not permit files over 10MB to be uploaded to the Asset Library for #{student.full_name} uploading #{asset.title}"

            else
              it 'appear in Asset Library search results'
              it 'appear in the Asset Library list view with the right title'
              it 'appear in the Asset Library list view with the right owner'
              it 'appear in the Asset Library detail view with the right title'
              it 'appear in the Asset Library detail view with the right owner'
              it 'appear in the Asset Library detail view with the right description'
              it 'appear in the Asset Library detail view with the right categories'
              it 'appear in the Asset Library detail view with the right source'
              it 'appear in the Asset Library detail view with the right preview type'
              it 'can be downloaded from the Asset Library detail view' if asset.file_name
              it 'cannot be downloaded from the Asset Library detail view' if asset.url
            end

          rescue => e
            it("tests hit an error with student #{student.uid} asset #{asset.inspect}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
          end
        end

      rescue => e
        it("tests hit an error with student #{student.inspect}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
      end
    end

  rescue => e
    it('tests hit an error initializing') { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
  ensure
    Utils.quit_browser @driver
  end
end
