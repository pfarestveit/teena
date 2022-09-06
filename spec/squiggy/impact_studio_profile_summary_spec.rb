require_relative '../../util/spec_helper'

describe 'Impact Studio' do

  test = SquiggyTestConfig.new 'profile_summary'

  teacher_viewer = test.course.teachers[0]
  teacher_share = test.course.teachers[1]
  teacher_no_share = test.course.teachers[2]

  student_viewer = test.course.students[0]
  student_share = test.course.students[1]
  student_no_share = test.course.students[2]

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
    @course.sections = [Section.new(label: @course.title)]
    @engagement_index.wait_for_new_user_sync(test, test.course.roster)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'Engagement Index card' do

    context 'when the Engagement Index is not present' do

      before(:all) { @canvas.disable_tool(test.course, SquiggyTool::ENGAGEMENT_INDEX) }

      context 'and an instructor' do

        before(:all) { @canvas.masquerade_as(test.course, teacher_viewer) }

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page test }
          it('shows no Engagement Index link') { expect(@impact_studio.engagement_index_link?).to be false }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views a student\'s Impact Studio profile' do
          before(:all) { @impact_studio.search_for_user student_viewer }
          it('shows no Engagement Index link') { expect(@impact_studio.engagement_index_link?).to be false }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end
      end

      context 'and a student' do

        before(:all) { @canvas.masquerade_as(student_viewer, test.course) }

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page test }
          it('shows no Engagement Index link') { expect(@impact_studio.engagement_index_link?).to be false }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views another student\'s Impact Studio profile' do
          before(:all) { @impact_studio.search_for_user student_share }
          it('shows no Engagement Index link') { expect(@impact_studio.engagement_index_link?).to be false }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end
      end
    end

    context 'when the Engagement Index is present' do

      before(:all) do
        @canvas.stop_masquerading
        @canvas.enable_tool(test.course, SquiggyTool::ENGAGEMENT_INDEX)

        @canvas.masquerade_as(teacher_share, test.course)
        @engagement_index.load_page test
        @engagement_index.share_score

        @canvas.masquerade_as(teacher_viewer, test.course)
        @engagement_index.load_page test
        @engagement_index.un_share_score

        @canvas.masquerade_as(teacher_no_share, test.course)
        @engagement_index.load_page test
        @engagement_index.un_share_score

        @canvas.masquerade_as(student_share, test.course)
        @engagement_index.load_page test
        @engagement_index.share_score

        @canvas.masquerade_as(student_viewer, test.course)
        @engagement_index.load_page test
        @engagement_index.un_share_score

        @canvas.masquerade_as(student_no_share, test.course)
        @engagement_index.load_page test
        @engagement_index.un_share_score
      end

      context 'and an instructor who has not shared its score' do

        before(:all) { @canvas.masquerade_as(teacher_viewer, test.course) }

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page test }
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows a "turn on" sharing link') { @impact_studio.turn_on_sharing_link_element.when_visible 1 }
        end

        context 'views the Impact Studio profile of an instructor who has not shared its score' do
          before(:all) do
            @engagement_index.load_page test
            @engagement_index.click_user_dashboard_link teacher_no_share
          end
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link_element.visible?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has shared its score' do
          before(:all) do
            @engagement_index.load_page test
            @engagement_index.click_user_dashboard_link teacher_share
          end
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has not shared its score' do
          before(:all) do
            @engagement_index.load_page test
            @engagement_index.click_user_dashboard_link student_no_share
          end
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has shared its score' do
          before(:all) do
            @engagement_index.load_page test
            @engagement_index.click_user_dashboard_link student_share
          end
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end
      end

      context 'and an instructor who has shared its score' do

        before(:all) do
          @canvas.masquerade_as(teacher_viewer, test.course)
          @engagement_index.load_page test
          @engagement_index.share_score
        end

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page test }
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has not shared its score' do
          before(:all) do
            @engagement_index.load_page test
            @engagement_index.click_user_dashboard_link teacher_no_share
          end
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has shared its score' do
          before(:all) do
            @engagement_index.load_page test
            @engagement_index.click_user_dashboard_link teacher_share
          end
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has not shared its score' do
          before(:all) do
            @engagement_index.load_page test
            @engagement_index.click_user_dashboard_link student_no_share
          end
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has shared its score' do
          before(:all) do
            @engagement_index.load_page test
            @engagement_index.click_user_dashboard_link student_share
          end
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end
      end

      context 'and a student who has not shared its score' do

        before(:all) { @canvas.masquerade_as(student_viewer, test.course) }

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page test }
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a "turn on" sharing link') { @impact_studio.turn_on_sharing_link_element.when_visible 1 }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has not shared its score' do
          before(:all) { @impact_studio.search_for_user teacher_no_share }
          it('shows no Engagement Index link') { @impact_studio.engagement_index_link_element.when_not_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has shared its score' do
          before(:all) { @impact_studio.search_for_user teacher_share }
          it('shows no Engagement Index link') { @impact_studio.engagement_index_link_element.when_not_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of a student who has not shared its score' do
          before(:all) { @impact_studio.search_for_user student_no_share }
          it('shows no Engagement Index link') { @impact_studio.engagement_index_link_element.when_not_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of a student who has shared its score' do
          before(:all) { @impact_studio.search_for_user student_share }
          it('shows no Engagement Index link') { @impact_studio.engagement_index_link_element.when_not_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end
      end

      context 'and a student who has shared its score' do

        before(:all) do
          @engagement_index.load_page test
          @engagement_index.share_score
        end

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page test }
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has not shared its score' do
          before(:all) { @impact_studio.search_for_user teacher_no_share }
          it('shows no Engagement Index link') { @impact_studio.engagement_index_link_element.when_not_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has shared its score' do
          before(:all) { @impact_studio.search_for_user teacher_share }
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has not shared its score' do
          before(:all) { @impact_studio.search_for_user student_no_share }
          it('shows no Engagement Index link') { @impact_studio.engagement_index_link_element.when_not_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of a student who has shared its score' do
          before(:all) { @impact_studio.search_for_user student_share }
          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end
      end
    end
  end

  describe 'profile summary' do

    before(:all) do
      @canvas.masquerade_as(student_viewer, test.course)
      @impact_studio.load_page test
    end

    it('shows the user name') { expect(@impact_studio.name).to eql(student_viewer.full_name) }
    it('shows the user avatar') { expect(@impact_studio.avatar?).to be true }

    it 'shows no sections section when there is no section' do
      @impact_studio.search_for_user teacher_no_share
      expect(@impact_studio.sections).to be_empty
    end

    it 'shows the sections when there are sections' do
      @impact_studio.search_for_user student_no_share
      expect(@impact_studio.sections).to eql(test.course.sections.map &:label)
    end

    describe 'last activity' do

      context 'when the user has no activity' do
        it 'shows "Never"' do
          expect(@impact_studio.last_activity).to eql('Never')
        end
      end

      context 'when the user has activity' do

        before(:all) do
          @asset_library.load_page test
          @asset_library.add_site SquiggyAsset.new title: "Asset #{test.id}",
                                                   url: 'www.google.com'
        end

        it 'shows the activity date' do
          @impact_studio.load_page test
          @impact_studio.wait_until(Utils.short_wait) { @impact_studio.last_activity == 'Today' }
        end
      end
    end

    describe 'description' do

      it 'allows the user to edit a description' do
        @impact_studio.edit_profile(desc = 'My personal description!')
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc == desc }
      end

      it 'allows the user to cancel a description edit' do
        desc = @impact_studio.profile_desc
        @impact_studio.click_edit_profile
        @impact_studio.enter_profile_desc 'This is not what I mean!'
        @impact_studio.cancel_profile_edit
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc == desc }
      end

      it 'allows the user to include a link in a description' do
        @impact_studio.edit_profile "My personal description includes a link to #{link = 'www.google.com'} !"
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc.include? 'My personal description includes a link to' }
        expect(@impact_studio.external_link_valid?(@impact_studio.link_element(xpath: "//a[contains(.,'#{link}')]"), 'Google'))
      end

      it 'allows the user to include a hashtag in a description' do
        @impact_studio.switch_to_canvas_iframe
        @impact_studio.edit_profile 'My personal description #BitterTogether'
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc.include? 'My personal description ' }
        sleep 2
        @impact_studio.link_element(text: '#BitterTogether').click
        @asset_library.wait_until(Utils.short_wait) { @asset_library.title == 'Asset Library' }
        @asset_library.switch_to_canvas_iframe
        @asset_library.no_search_results_element.when_visible Utils.short_wait
      end

      it 'allows the user to add a maximum of X characters to a description' do
        @impact_studio.load_page test
        @impact_studio.click_edit_profile
        @impact_studio.enter_profile_desc(desc = "#{'A loooooong title' * 15}?")
        @impact_studio.char_limit_msg_element.when_visible 1
        @impact_studio.cancel_profile_edit
        @impact_studio.edit_profile(desc = desc[0, 255])
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc == desc }
      end

      it 'allows the user to remove a description' do
        @impact_studio.edit_profile ''
        sleep 1
        @impact_studio.profile_desc_element.when_not_visible Utils.short_wait
      end
    end
  end

  describe '"looking for collaborators"' do

    context 'when the user is not looking' do

      before(:all) do
        @canvas.masquerade_as(student_viewer, test.course)
        @impact_studio.load_page test
      end

      context 'and the user views itself' do

        it('shows the right status on the Impact Studio') { @impact_studio.set_collaboration_false }
      end

      context 'and another user views the user' do

        before(:all) do
          @canvas.masquerade_as(student_share, test.course)
          @impact_studio.load_page test
          @impact_studio.search_for_user student_viewer
        end

        it('shows no collaboration element on the Impact Studio') { expect(@impact_studio.collaboration_button?).to be false }
      end
    end

    context 'when the user is looking' do

      before(:all) do
        @canvas.masquerade_as(student_viewer, test.course)
        @impact_studio.load_page test
      end

      context 'and the user views itself' do

        it('shows the right status on the Impact Studio') { @impact_studio.set_collaboration_true }
      end

      context 'and another user views the user' do

        before(:all) do
          @canvas.masquerade_as(student_share, test.course)
          @impact_studio.load_page test
          @impact_studio.search_for_user student_viewer
        end

        it('shows a collaborate button on the Impact Studio') { expect(@impact_studio.collaboration_button?).to be true }
      end
    end
  end
end
