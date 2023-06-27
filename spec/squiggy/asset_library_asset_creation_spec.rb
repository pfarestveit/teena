require_relative '../../util/spec_helper'

include Logging

describe 'New asset' do

  begin
    @test = SquiggyTestConfig.new 'asset_creation'
    @test.course_site.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course_site @test

    @test.students.each do |student|
      begin
        @canvas.masquerade_as(student, @test.course_site)
        @assets_list.load_page @test

        student.assets.each do |asset|
          begin
            asset_rejected = false
            @asset_detail.click_back_to_asset_library if @asset_detail.back_to_asset_library_button?

            if asset.file_name
              @assets_list.click_upload_file_button
              @assets_list.enter_file_path_for_upload asset
              if asset.size.to_f / 1024000 > 10
                asset_rejected = @assets_list.verify_block { @assets_list.upload_error_element.when_visible Utils.short_wait }
                it "#{asset.title} belonging to #{student.full_name} cannot be uploaded to the Asset Library because it is over 10MB" do
                  expect(asset_rejected).to be true
                end
              else
                format_warning = @assets_list.verify_block { @assets_list.unsupported_format_element.when_visible 3 }
                if SquiggyAsset::NO_PREVIEW_EXTENSIONS.include? asset.file_name.split('.').last
                  it "#{asset.title} belonging to #{student.full_name} triggers a no-preview warning" do
                    expect(format_warning).to be true
                  end
                else
                  it "#{asset.title} belonging to #{student.full_name} triggers no no-preview warning" do
                    expect(format_warning).to be false
                  end
                end
                @assets_list.enter_asset_metadata asset
                @assets_list.click_add_files_button
                @assets_list.get_asset_id asset
              end
            else
              @assets_list.add_link_asset asset
            end

            unless asset_rejected
              @assets_list.wait_for_assets @test
              visible_asset = @assets_list.visible_list_view_asset_data asset

              it("#{asset.title} belonging to #{student.full_name} has the right list view title") { expect(visible_asset[:title]).to eql(asset.title) }
              it("#{asset.title} belonging to #{student.full_name} has the right list view owner") { expect(visible_asset[:owner]).to eql(student.full_name) }

              @assets_list.click_asset_link(@test, asset)
              visible_detail = @asset_detail.visible_asset_metadata asset
              expected_desc = (asset.description && !asset.description.empty?) ? asset.description : '—'
              preview_generated = @asset_detail.preview_generated? asset
              asset_downloadable = @asset_detail.verify_block { @asset_detail.download_asset asset } if asset.file_name
              has_download_button = @asset_detail.download_button?

              it("#{asset.title} belonging to #{student.full_name} has the right detail view title") { expect(visible_detail[:title]).to eql(asset.title) }
              it("#{asset.title} belonging to #{student.full_name} has the right detail view owner") { expect(visible_detail[:owner]).to eql(student.full_name) }
              it("#{asset.title} belonging to #{student.full_name} has the right detail view description") { expect(visible_detail[:description]).to eql(expected_desc) }
              it("#{asset.title} belonging to #{student.full_name} has the right detail view preview type") { expect(preview_generated).to be true }
              it("#{asset.title} belonging to #{student.full_name} has the right detail view category") { expect(visible_detail[:category]).to be true }

              if asset.file_name
                it "#{asset.title} belonging to #{student.full_name} can be downloaded from the Asset Library detail view" do
                  expect(asset_downloadable).to be true
                end
                it "#{asset.title} belonging to #{student.full_name} has no detail view source" do
                  expect(visible_detail[:source_exists]).to be false
                end
              else
                it "#{asset.title} belonging to #{student.full_name} cannot be downloaded from the Asset Library detail view" do
                  expect(has_download_button).to be false
                end
                it "#{asset.title} belonging to #{student.full_name} has the right detail view source" do
                  expect(visible_detail[:source]).to be_truthy
                end
              end

              regen_button = @asset_detail.regenerate_preview_button?
              if asset.url
                it("#{asset.title} belonging to #{student.full_name} offers a regenerate-preview button") { expect(regen_button).to be true }

                if asset.url.include? 'jamboard.google.com'
                  preview_triggered = @asset_detail.verify_block do
                    sleep 2
                    @asset_detail.click_regenerate_preview
                    @asset_detail.preparing_preview_msg_element.when_visible Utils.short_wait
                  end
                  it("#{asset.title} belonging to #{student.full_name} can trigger a preview refresh") { expect(preview_triggered).to be true }

                  preview_regenerated = @asset_detail.preview_generated? asset
                  it("#{asset.title} belonging to #{student.full_name} regenerates the right detail view preview type") { expect(preview_regenerated).to be true }
                end

              else
                it("#{asset.title} belonging to #{student.full_name} offers no regenerate-preview button") { expect(regen_button).to be false }
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
