require_relative '../../util/spec_helper'

include Logging

describe 'New asset uploads', order: :defined do

  begin

    timeout = Utils.short_wait
    test_id = Utils.get_test_id

    @course = Course.new({title: "Asset Library Content #{test_id}"})
    @course.site_id = ENV['COURSE_ID']
    user_test_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['asset_library_content'] }
    users = user_test_data.map { |user_data| User.new(user_data) }

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryDetailPage.new @driver

    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, Utils.get_test_id, [LtiTools::ASSET_LIBRARY])

    @canvas.load_course_site(@driver, @course)
    @asset_library_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY)

    users.each do |user|

      begin
        @canvas.masquerade_as(@driver, user, @course)
        user_full_name = user.full_name
        user.assets.each do |asset|

          begin
            @asset = Asset.new asset
            asset_title = (@asset.title = "#{@asset.title} #{test_id}")
            asset_preview_type = @asset.preview
            @asset.description = nil
            @asset.category = nil
            @asset_size = File.size(SuiteCUtils.test_data_file_path(@asset.file_name)).to_f / 1024000
            @asset_library.load_page(@driver, @asset_library_url)

            if @asset.type == 'File'
              asset_file_name = @asset.file_name

              # Excessively large files should be rejected
              if @asset_size > 10

                @asset_library.click_upload_file_link
                @asset_library.enter_file_path_for_upload @asset.file_name
                asset_rejected = @asset_library.verify_block { @asset_library.upload_error_element.when_visible timeout }

                it("do not permit files over 10MB to be uploaded to the Asset Library for #{user_full_name} uploading #{asset_title}") { expect(asset_rejected).to be true }

              else

                @asset_library.upload_file_to_library @asset
                @asset_library.wait_until(Utils.long_wait) { @asset_library.list_view_asset_elements.any? }
                file_uploaded = @asset_library.verify_block { @asset_library.verify_first_asset(user, @asset) }
                preview_generated = @asset_library.preview_generated?(@driver, @asset_library_url, @asset, user)
                asset_downloadable = @asset_library.verify_block { @asset_library.download_asset @asset }

                it("appear in the Asset Library for #{user_full_name} uploading #{asset_title}") { expect(file_uploaded).to be true }
                it("generate a preview of type #{asset_preview_type} for #{user_full_name} uploading #{asset_file_name}") { expect(preview_generated).to be true }
                it("can be downloaded by #{user_full_name} from the #{asset_title} asset detail page") { expect(asset_downloadable).to be true }

              end

            elsif @asset.type == 'Link'
              asset_url = @asset.url

              @asset_library.add_site @asset
              @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
              url_uploaded = @asset_library.verify_block { @asset_library.verify_first_asset(user, @asset) }
              preview_generated = @asset_library.preview_generated?(@driver, @asset_library_url, @asset, user)
              has_download_button = @asset_library.download_asset_link?

              it("appear in the Asset Library for #{user_full_name} uploading #{asset_title}") { expect(url_uploaded).to be true }
              it("generate a preview of type #{asset_preview_type} for #{user_full_name} adding link #{asset_url}") { expect(preview_generated).to be true }
              it("cannot be downloaded by #{user_full_name} from the #{asset_title} detail page") { expect(has_download_button).to be false }

            else

              it("could not process an invalid asset type '#{asset_title}' for #{user_full_name}") { fail }

            end

          rescue => e
            # Catch and report errors related to the asset
            logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
            it("caused an unexpected error for #{user_full_name}'s asset '#{asset_title}'") { fail }
          end
        end

      rescue => e
        # Catch and report errors related to the user
        logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
        it("caused an unexpected error for #{user_full_name}") { fail }
      ensure
        @canvas.stop_masquerading @driver
      end
    end

  rescue => e
    # Catch and report errors related to the whole test
    logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
    it('caused an unexpected error') { fail }
  ensure
    @driver.quit
  end
end
