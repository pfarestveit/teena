require_relative '../../util/spec_helper'

include Logging

describe 'New asset' do

  begin
    @test = SquiggyTestConfig.new 'asset_creation'
    @test.course.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @test.students.each do |student|
      begin
        @canvas.masquerade_as(student, @test.course)
        @assets_list.load_page @test

        student.assets.each do |asset|
          begin
            @asset_detail.click_back_to_asset_library if @asset_detail.back_to_asset_library_button?

            if asset.file_name
              if asset.size.to_f / 1024000 > 10
                @assets_list.click_upload_file_button
                @assets_list.enter_file_path_for_upload asset
                asset_rejected = @assets_list.verify_block { @assets_list.upload_error_element.when_visible Utils.short_wait }
                it "#{asset.title} belonging to #{student.full_name} cannot be uploaded to the Asset Library because it is over 10MB" do
                  expect(asset_rejected).to be true
                end
              else
                @assets_list.upload_file_asset asset
              end
            else
              @assets_list.add_link_asset asset
            end

            @assets_list.wait_for_assets
            visible_asset = @assets_list.visible_list_view_asset_data asset

            it("#{asset.title} belonging to #{student.full_name} has the right list view title") { expect(visible_asset[:title]).to eql(asset.title) }
            it("#{asset.title} belonging to #{student.full_name} has the right list view owner") { expect(visible_asset[:owner]).to eql(student.full_name) }

            @assets_list.click_asset_link asset
            visible_detail = @asset_detail.visible_asset_metadata
            preview_generated = @asset_detail.preview_generated? asset
            asset_downloadable = @asset_detail.verify_block { @asset_detail.download_asset asset } if asset.file_name
            has_download_button = @asset_detail.download_button?

            it("#{asset.title} belonging to #{student.full_name} has the right detail view title") { expect(visible_detail[:title]).to eql(asset.title) }
            it("#{asset.title} belonging to #{student.full_name} has the right detail view owner") { expect(visible_detail[:owner]).to eql(student.full_name) }
            it("#{asset.title} belonging to #{student.full_name} has the right detail view description") { expect(visible_detail[:description]).to eql(asset.description.to_s) }
            it("#{asset.title} belonging to #{student.full_name} has the right detail view preview type") { expect(preview_generated).to be true }

            it "#{asset.title} belonging to #{student.full_name} has the right detail view category" do
              # TODO
            end

            it "#{asset.title} belonging to #{student.full_name} has the right detail view source" do
              # TODO
            end

            if asset.file_name
              it "#{asset.title} belonging to #{student.full_name} can be downloaded from the Asset Library detail view" do
                expect(asset_downloadable).to be true
              end
            else
              it "#{asset.title} belonging to #{student.full_name} cannot be downloaded from the Asset Library detail view" do
                expect(has_download_button).to be false
              end
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
