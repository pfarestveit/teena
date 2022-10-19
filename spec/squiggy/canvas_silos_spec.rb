require_relative '../../util/spec_helper'

include Logging

describe 'Canvas section silo-ing' do

  before(:all) do
    @test = SquiggyTestConfig.new 'canvas_silos'
    @section_1 = Section.new label: "WBL 001 #{@test.id}", sis_id: "WBL 001 #{@test.id}"
    @section_2 = Section.new label: "WBL 002 #{@test.id}", sis_id: "WBL 002 #{@test.id}"
    @test.course.sections = [@section_1, @section_2]
    (@teacher = @test.teachers.first).sections = [@section_2]
    (@student_1 = @test.students[0]).sections = [@section_1]
    (@student_2 = @test.students[1]).sections = [@section_1]
    (@student_3 = @test.students[2]).sections = [@section_1, @section_2]
    (@student_4 = @test.students[3]).sections = [@section_2]
    (@student_5 = @test.students[4]).sections = [@section_2]
    @section_1_assets = [@student_1.assets[0], @student_2.assets[0], @student_3.assets[0]]
    @section_2_assets = [@student_3.assets[0], @student_4.assets[0], @student_5.assets[0]]
    @section_1_and_2_whiteboard = SquiggyWhiteboard.new title: "Sections 1 and 2 #{@test.id}",
                                                        owner: @teacher,
                                                        collaborators: @test.students
    @section_1_whiteboard = SquiggyWhiteboard.new title: "Section 1 #{@test.id}",
                                                  owner: @student_1,
                                                  collaborators: [@student_2, @student_3]
    @section_2_whiteboard = SquiggyWhiteboard.new title: "Section 2 #{@test.id}",
                                                  owner: @student_3,
                                                  collaborators: [@student_1, @student_4, @student_5]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasAssignmentsPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver
    @whiteboards = SquiggyWhiteboardPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test
    @engagement_index.wait_for_new_user_sync(@test, @test.course.roster)
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when enabled' do

    before(:all) do
      @canvas.masquerade_as(@teacher, @test.course)
      @asset_library.load_page @test
      @asset_library.click_manage_assets_link
      @manage_assets.silo_sections
    end

    context 'on the Asset Library' do

      before(:all) do
        @test.students.each do |student|
          asset = student.assets.first
          @canvas.masquerade_as(student, @test.course)
          @asset_library.load_page @test
          asset.file_name ? @asset_library.upload_file_asset(asset) : @asset_library.add_link_asset(asset)
        end
      end

      context 'viewed by an instructor' do

        before(:all) { @canvas.masquerade_as(@teacher, @test.course) }

        it 'allows access to all assets' do
          (@section_1_assets + @section_2_assets).uniq.each { |asset| @asset_library.load_asset_detail(@test, asset) }
        end
      end

      context 'viewed by a student' do

        before(:all) { @canvas.masquerade_as(@student_1, @test.course) }

        it 'allows access to assets belonging to the same section as the student' do
          @section_1_assets.each { |asset| @asset_library.load_asset_detail(@test, asset) }
        end

        it 'prevents access to assets belonging to a different section than the user' do
          [@student_4.assets[0], @student_5.assets[0]].each { |asset| @asset_library.hit_unavailable_asset(@test, asset) }
        end
      end

      context 'simple search' do

        context 'viewed by an instructor' do

          before(:all) do
            @canvas.masquerade_as(@teacher, @test.course)
            @asset_library.load_page @test
          end

          it 'shows results for all sections' do
            @asset_library.simple_search @test.id
            @asset_library.wait_for_asset_results (@section_1_assets + @section_2_assets).uniq.sort_by(&:id).reverse
          end
        end

        context 'viewed by a student' do

          it 'with single section citizenship shows results for a single section' do
            @canvas.masquerade_as(@student_1, @test.course)
            @asset_library.load_page @test
            @asset_library.simple_search @test.id
            @asset_library.wait_for_asset_results (@section_1_assets).sort_by(&:id).reverse

            @canvas.masquerade_as(@student_5, @test.course)
            @asset_library.load_page @test
            @asset_library.simple_search @test.id
            @asset_library.wait_for_asset_results (@section_2_assets).sort_by(&:id).reverse
          end

          it 'with dual section citizenship shows results for multiple sections' do
            @canvas.masquerade_as(@student_3, @test.course)
            @asset_library.load_page @test
            @asset_library.simple_search @test.id
            @asset_library.wait_for_asset_results (@section_1_assets + @section_2_assets).uniq.sort_by(&:id).reverse
          end
        end
      end

      context 'advanced search' do

        context 'viewed by an instructor' do

          before(:all) do
            @canvas.masquerade_as(@teacher, @test.course)
            @asset_library.load_page @test
          end

          it 'shows results for all sections' do
            @asset_library.advanced_search(@test.id, nil, nil, nil, nil, nil)
            @asset_library.wait_for_asset_results (@section_1_assets + @section_2_assets).uniq.sort_by(&:id).reverse
          end

          it('allows an instructor to filter results by section') { expect(@asset_library.section_select?).to be true }
        end

        context 'viewed by a student' do

          it 'with single section citizenship shows results for a single section' do
            @canvas.masquerade_as(@student_1, @test.course)
            @asset_library.load_page @test
            @asset_library.advanced_search(@test.id, nil, nil, nil, nil, nil)
            @asset_library.wait_for_asset_results (@section_1_assets).sort_by(&:id).reverse

            @canvas.masquerade_as(@student_5, @test.course)
            @asset_library.load_page @test
            @asset_library.advanced_search(@test.id, nil, nil, nil, nil, nil)
            @asset_library.wait_for_asset_results (@section_2_assets).sort_by(&:id).reverse
          end

          it 'with dual section citizenship shows results for all their sections' do
            @canvas.masquerade_as(@student_3, @test.course)
            @asset_library.load_page @test
            @asset_library.advanced_search(@test.id, nil, nil, nil, nil, nil)
            @asset_library.wait_for_asset_results (@section_1_assets + @section_2_assets).uniq.sort_by(&:id).reverse
          end

          it('does not offer a section filter') { expect(@asset_library.section_select?).to be false }
        end
      end
    end

    context 'on the Engagement Index' do

      before(:all) do
        @test.students.each do | student|
          @canvas.masquerade_as(student, @test.course)
          @engagement_index.load_page @test
          @engagement_index.share_score
        end
      end

      context 'viewed by an instructor' do

        before(:all) do
          @canvas.masquerade_as(@teacher, @test.course)
          @engagement_index.load_page @test
          @engagement_index.wait_for_scores
        end

        it 'shows all students and their sections' do
          expect(@engagement_index.visible_names.sort).to eql(@test.course.roster.map(&:full_name).sort)
          expect(@engagement_index.visible_sections.sort).to eql(@test.course.sections.map(&:sis_id).sort)
        end

        it 'includes student sections in the CSV export' do
          csv = @engagement_index.download_csv @test
          expected = [@section_1.sis_id, "#{@section_1.sis_id}, #{@section_2.sis_id}", @section_2.sis_id]
          expect(@engagement_index.csv_sections(csv).sort).to eql(expected)
        end
      end

      context 'viewed by a student' do

        it 'with single section citizenship shows students in their own section only' do
          @canvas.masquerade_as(@student_1, @test.course)
          @engagement_index.load_page @test
          @engagement_index.wait_for_scores
          expect(@engagement_index.visible_names.sort).to eql([@student_1, @student_2, @student_3].map(&:full_name).sort)
        end

        it 'with dual section citizenship shows students in all their sections' do
          @canvas.masquerade_as(@student_3, @test.course)
          @engagement_index.load_page @test
          @engagement_index.wait_for_scores
          expect(@engagement_index.visible_names.sort).to eql(@test.students.map(&:full_name).sort)
        end

        it('does not show students section information') { expect(@engagement_index.sort_by_section?).to be false }
      end
    end

    context 'on Whiteboards' do

      context 'viewed by an instructor' do

        before(:all) do
          @canvas.masquerade_as(@teacher, @test.course)
          @whiteboards.load_page @test
        end

        it 'offers all section students for adding to a whiteboard' do
          @whiteboards.create_and_open_whiteboard @section_1_and_2_whiteboard
          @whiteboards.add_existing_assets [@student_1.assets[0], @student_3.assets[0], @student_5.assets[0]]
          @whiteboards.export_to_asset_library(@section_1_and_2_whiteboard, "#{@section_1_and_2_whiteboard.title} version 1")
          @section_1_assets << @section_1_and_2_whiteboard.asset_exports[0]
          @section_2_assets << @section_1_and_2_whiteboard.asset_exports[0]
        end

        it 'offers all section assets for adding to a whiteboard' do
          @whiteboards.add_existing_assets [@student_3.assets[0]]
          @whiteboards.export_to_asset_library(@section_1_and_2_whiteboard, "#{@section_1_and_2_whiteboard.title} version 2")
          @section_1_assets << @section_1_and_2_whiteboard.asset_exports[1]
          @section_2_assets << @section_1_and_2_whiteboard.asset_exports[1]
        end
      end

      context 'viewed by a student' do

        before(:all) do
          @whiteboards.close_whiteboard
          @canvas.masquerade_as(@student_1, @test.course)
          @whiteboards.load_page @test
        end

        it 'offers others from the student\'s section for adding to a whiteboard' do
          @whiteboards.click_add_whiteboard
          @whiteboards.click_collaborators_input
          @whiteboards.collaborator_option_link(@student_2).when_present 2
          expect(@whiteboards.collaborator_option_link(@student_3).exists?).to be true
          expect(@whiteboards.collaborator_option_link(@student_4).exists?).to be false
          expect(@whiteboards.collaborator_option_link(@student_5).exists?).to be false
        end

        it 'offers assets from the student\'s section for adding to a whiteboard' do
          @whiteboards.hit_escape
          @whiteboards.click_cancel_button
          @whiteboards.create_and_open_whiteboard @section_1_whiteboard
          @whiteboards.click_add_existing_asset
          @whiteboards.wait_until(Utils.short_wait) { @whiteboards.add_asset_cbx_elements.any? }
          expect(@whiteboards.asset_ids_available_to_add.sort).to eql(@section_1_assets.map(&:id).sort)
        end

        it 'allows exporting as an asset in their own section' do
          @whiteboards.hit_escape
          @whiteboards.add_existing_assets @section_1_assets
          @section_1_assets << @whiteboards.export_to_asset_library(@section_1_whiteboard)
        end
      end
    end

    context 'on the Impact Studio' do

      context 'viewed by an instructor' do

        before(:all) do
          @canvas.masquerade_as(@teacher, @test.course)
          @impact_studio.load_page @test
        end

        it 'shows Everyone\'s Assets for all students' do
          assets = (@section_1_assets + @section_2_assets).uniq
          @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_recent(assets)
        end

        it 'offers profile options for all students and instructors' do
          expect(@impact_studio.visible_user_select_options.sort).to eql(@test.course.roster.map(&:full_name).sort)
        end

        it 'offers profile browsing for all students and instructors' do
          @test.course.roster.sort_by! { |u| u.full_name }
          index_of_current_user = @test.course.roster.index @teacher
          @test.course.roster.rotate!(index_of_current_user + 1)
          @test.course.roster.each { |user| @impact_studio.browse_next_user user }
        end

        it 'shows the activity network for all students' do
          @impact_studio.load_page @test
          @impact_studio.select_user @student_1
          expect(@impact_studio.visible_network_user_ids.sort).to eql(@test.students.map(&:squiggy_id).sort)
        end

        it 'shows the activity timeline for all students' do
          # TODO
        end
      end

      context 'viewed by a student' do

        before(:all) do
          @canvas.masquerade_as(@student_1, @test.course)
          @impact_studio.load_page @test
        end

        it 'offers profile options for students in their own sections and instructors' do
          expected = [@student_1, @student_2, @student_3, @teacher]
          expect(@impact_studio.visible_user_select_options.sort).to eql(expected.map(&:full_name).sort)
        end

        it 'shows Everyone\'s Assets for students in their own sections' do
          @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_recent(@section_1_assets)
        end

        it 'shows the activity network for students in their own sections' do
          expect(@impact_studio.visible_network_user_ids.sort).to eql([@student_1, @student_2, @student_3].map(&:squiggy_id).sort)
        end

        it 'offers profile browsing for students in their own sections' do
          expected = [@student_1, @student_2, @student_3, @teacher]
          expected.sort_by! { |u| u.full_name }
          index_of_current_user = expected.index @student_1
          expected.rotate!(index_of_current_user + 1)
          expected.each { |user| @impact_studio.browse_next_user user }
        end

        it 'shows the activity timeline for students in their own sections' do
          # TODO
        end
      end
    end

    context 'and a student switches sections' do

      before(:all) do
        @canvas.masquerade_as @student_3
        @whiteboards.load_page @test
        @whiteboards.create_and_open_whiteboard @section_2_whiteboard
        @whiteboards.close_whiteboard

        @comment = SquiggyComment.new asset: @section_1_and_2_whiteboard.asset_exports.first,
                                      body: "#{@test.id} Student 3's comment on shared asset",
                                      user: @student_3
        @asset_library.load_asset_detail(@test, @section_1_and_2_whiteboard.asset_exports.first)
        @asset_library.add_comment @comment
        @canvas.stop_masquerading

        @canvas.remove_user_section(@test.course, @student_3, @section_1)
        @engagement_index.wait_for_user_sections(@test, @student_3)
        @section_1_assets.delete_if { |a| a.owner == @student_3 }
        @section_1_whiteboard.collaborators.delete @student_1
      end

      context 'the student' do

        before(:all) { @canvas.masquerade_as @student_3 }

        it('can reach its own assets') { @asset_library.load_asset_detail(@test, @student_3.asset.first) }

        it 'can search for assets in the new silo only' do
          @asset_library.load_page @test
          @asset_library.advanced_search(@test.id, nil, nil, nil, nil, nil)
          @asset_library.wait_for_asset_results @section_2_assets.uniq.sort_by(&:id).reverse
        end

        it 'can see EI scores of students in the new silo only' do
          @engagement_index.load_page @test
          @engagement_index.wait_for_scores
          expect(@engagement_index.visible_names.sort).to eql([@student_3, @student_4, @student_5].map(&:full_name).sort)
        end

        it 'can see own whiteboards' do
          @whiteboards.load_page @test
          @whiteboards.wait_until(Utils.short_wait) { @whiteboards.visible_whiteboard_titles.any? }
          expected = [@section_2_whiteboard, @section_1_and_2_whiteboard].map(&:title).sort
          expect(@whiteboards.visible_whiteboard_titles.sort).to eql(expected)
        end

        it 'loses membership in a whiteboard owned by a student in the former silo' do
          @whiteboards.hit_whiteboard_url @section_1_whiteboard
          has_access = @whiteboards.verify_block { @whiteboards.settings_button_element.when_visible 2 }
          expect(has_access).to be false
        end

        it 'can only view the IS profiles of students in the new silo' do
          @impact_studio.load_page @test
          expected = [@student_3, @student_4, @student_5, @teacher]
          expect(@impact_studio.visible_user_select_options.sort).to eql(expected.map(&:full_name).sort)
        end

        it 'can only view the IS activity network of students in the new silo' do
          expect(@impact_studio.visible_network_user_ids.sort).to eql([@student_3, @student_4, @student_5].map(&:squiggy_id).sort)
        end

        it 'can only view the IS everyone assets of students in the new silo' do
          @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_recent(@section_2_assets)
        end

        it 'can only view the IS activity timeline of students in the new silo' do
          # TODO
        end
      end

      context 'the student\'s former silo mates' do

        before(:all) { @canvas.masquerade_as(@student_1, @test.course) }

        it('can no longer reach the student\'s assets') { @asset_library.hit_unavailable_asset(@test, @student_3.assets.first) }

        it 'can no longer search for the student\'s assets' do
          @asset_library.load_page @test
          @asset_library.advanced_search(@test.id, nil, nil, nil, nil, nil)
          @asset_library.wait_for_asset_results @section_1_assets.uniq.sort_by(&:id).reverse
        end

        it 'can no longer view the student\'s assets via a link on an asset comment' do
          @asset_library.load_asset_detail(@test, @section_1_and_2_whiteboard.asset_exports.first)
          @asset_library.comment_el_by_id(@comment).when_present Utils.short_wait
          expect(@asset_library.commenter_link(@comment).exists?).to be false
        end

        it 'can no longer see the student\'s EI score' do
          @engagement_index.load_page @test
          @engagement_index.wait_for_scores
          expect(@engagement_index.visible_names.sort).to eql([@student_1, @student_2].map(&:full_name).sort)
        end

        it 'are removed from the student\'s whiteboards' do
          @whiteboards.hit_whiteboard_url @section_2_whiteboard
          has_access = @whiteboards.verify_block { @whiteboards.settings_button_element.when_visible 2 }
          expect(has_access).to be false
        end

        it 'can no longer view the student\'s IS profile' do
          @impact_studio.load_page @test
          expected = [@student_1, @student_2, @teacher]
          expect(@impact_studio.visible_user_select_options.sort).to eql(expected.map(&:full_name).sort)
        end

        it 'can no longer view the student\'s IS activity network' do
          expect(@impact_studio.visible_network_user_ids.sort).to eql([@student_1, @student_2].map(&:squiggy_id).sort)
        end

        it 'can no longer view the student\'s IS everyone assets' do
          @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_recent(@section_1_assets)
        end

        it 'can no longer view the student\'s IS activity timeline' do
          # TODO
        end
      end
    end
  end
end
