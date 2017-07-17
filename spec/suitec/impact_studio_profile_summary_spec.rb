require_relative '../../util/spec_helper'

describe 'Impact Studio', order: :defined do

  include Logging
  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id

  # Get test users
  user_test_data = Utils.load_test_users.select { |data| data['tests']['impact_studio_profile'] }
  users = user_test_data.map { |data| User.new(data) if ['Teacher', 'Designer', 'Lead TA', 'TA', 'Observer', 'Reader', 'Student'].include? data['role'] }

  teachers = users.select { |user| %w(Teacher TA).include? user.role }
  teacher_viewer = teachers[0]
  teacher_share = teachers[1]
  teacher_no_share = teachers[2]

  students = users.select { |user| user.role == 'Student' }
  student_viewer = students[0]
  student_share = students[1]
  student_no_share = students[2]

  before(:all) do
    @course = Course.new({title: "Impact Studio Profile #{test_id}", code: "Impact Studio Profile #{test_id}", site_id: course_id})

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @impact_studio = Page::SuiteCPages::ImpactStudioPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    # Create course site if necessary
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::IMPACT_STUDIO, SuiteCTools::ENGAGEMENT_INDEX])
    @course.sections = [Section.new({label: @course.title})]
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @impact_studio_url = @canvas.click_tool_link(@driver, SuiteCTools::IMPACT_STUDIO)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)
    @engagement_index.wait_for_new_user_sync(@driver, @engagement_index_url, users)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'Engagement Index card' do

    context 'when the Engagement Index is not present' do

      before(:all) { @canvas.disable_tool(@course, SuiteCTools::ENGAGEMENT_INDEX) }

      context 'and an instructor' do

        before(:all) { @canvas.masquerade_as(@driver, teacher_viewer, @course) }

        context 'views its own Impact Studio profile' do

          before(:all) do
            @impact_studio.load_page(@driver, @impact_studio_url)
            sleep 3
          end

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

        before(:all) { @canvas.masquerade_as(@driver, student_viewer, @course) }

        context 'views its own Impact Studio profile' do

          before(:all) do
            @impact_studio.load_page(@driver, @impact_studio_url)
            sleep 3
          end

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
        @canvas.stop_masquerading @driver
        @canvas.add_suite_c_tool(@course, SuiteCTools::ENGAGEMENT_INDEX)
        @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)

        # One teacher shares score
        @canvas.masquerade_as(@driver, teacher_share, @course)
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.share_score

        # Two teachers do not share score
        @canvas.masquerade_as(@driver, teacher_viewer, @course)
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.un_share_score

        @canvas.masquerade_as(@driver, teacher_no_share, @course)
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.un_share_score

        # One student shares score
        @canvas.masquerade_as(@driver, student_share, @course)
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.share_score

        # Two students do not share score
        @canvas.masquerade_as(@driver, student_viewer, @course)
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.un_share_score

        @canvas.masquerade_as(@driver, student_no_share, @course)
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.un_share_score
      end

      context 'and an instructor who has not shared its score' do

        before(:all) { @canvas.masquerade_as(@driver, teacher_viewer, @course) }

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows a "turn on" sharing link') { @impact_studio.turn_on_sharing_link_element.when_visible 1 }
        end

        context 'views the Impact Studio profile of an instructor who has not shared its score' do
          before(:all) do
            @engagement_index.load_page(@driver, @engagement_index_url)
            @engagement_index.click_user_dashboard_link(@driver, teacher_no_share)
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link_element.visible?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has shared its score' do
          before(:all) do
            @engagement_index.load_page(@driver, @engagement_index_url)
            @engagement_index.click_user_dashboard_link(@driver, teacher_share)
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has not shared its score' do
          before(:all) do
            @engagement_index.load_page(@driver, @engagement_index_url)
            @engagement_index.click_user_dashboard_link(@driver, student_no_share)
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has shared its score' do
          before(:all) do
            @engagement_index.load_page(@driver, @engagement_index_url)
            @engagement_index.click_user_dashboard_link(@driver, student_share)
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
          @canvas.masquerade_as(@driver, teacher_viewer, @course)
          @engagement_index.load_page(@driver, @engagement_index_url)
          @engagement_index.share_score
        end

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has not shared its score' do
          before(:all) do
            @engagement_index.load_page(@driver, @engagement_index_url)
            @engagement_index.click_user_dashboard_link(@driver, teacher_no_share)
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has shared its score' do
          before(:all) do
            @engagement_index.load_page(@driver, @engagement_index_url)
            @engagement_index.click_user_dashboard_link(@driver, teacher_share)
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has not shared its score' do
          before(:all) do
            @engagement_index.load_page(@driver, @engagement_index_url)
            @engagement_index.click_user_dashboard_link(@driver, student_no_share)
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end

        context 'views the Impact Studio profile of a student who has shared its score' do
          before(:all) do
            @engagement_index.load_page(@driver, @engagement_index_url)
            @engagement_index.click_user_dashboard_link(@driver, student_share)
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows a score') { @impact_studio.engagement_index_score_element.when_visible 1 }
          it('shows a rank') { @impact_studio.engagement_index_rank_element.when_visible 1 }
          it('shows a rank total') { @impact_studio.engagement_index_rank_ttl_element.when_visible 1 }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
        end
      end

      context 'and a student who has not shared its score' do

        before(:all) { @canvas.masquerade_as(@driver, student_viewer, @course) }

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

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
          @engagement_index.load_page(@driver, @engagement_index_url)
          @engagement_index.share_score
        end

        context 'views its own Impact Studio profile' do
          before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

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
      @canvas.masquerade_as(@driver, @course, student_viewer)
      @impact_studio.load_page(@driver, @impact_studio_url)
    end

    it('shows the user name') { expect(@impact_studio.name).to eql(student_viewer.full_name) }
    it('shows the user avatar') { expect(@impact_studio.avatar?).to be true }

    it 'shows no sections section when there is no section' do
      @impact_studio.search_for_user teacher_no_share
      expect(@impact_studio.sections).to be_empty
    end

    it 'shows the sections when there are sections' do
      @impact_studio.search_for_user student_no_share
      expect(@impact_studio.sections).to eql(@course.sections.map &:label)
    end

    describe 'last activity' do

      context 'when the user has no activity' do
        it('shows "Never"') do
          course_id.nil? ?
              (expect(@impact_studio.last_activity).to eql('Never')) :
              logger.warn('Skipping the test for last activity "Never", since this is not a new course site')
        end
      end

      context 'when the user has activity' do

        before(:all) do
          @asset_library.load_page(@driver, @asset_library_url)
          @asset_library.add_site Asset.new(title: "Asset #{test_id}", url: 'www.google.com')
        end

        it 'shows the activity date' do
          @impact_studio.load_page(@driver, @impact_studio_url)
          @impact_studio.wait_until(Utils.short_wait) { @impact_studio.last_activity == 'Today' }
        end
      end
    end

    describe 'description' do

      it 'allows the user to edit a description' do
        @impact_studio.edit_profile (desc = 'My personal description!')
        @impact_studio.wait_until { @impact_studio.profile_desc == desc }
      end

      it 'allows the user to cancel a description edit' do
        desc = @impact_studio.profile_desc
        @impact_studio.click_edit_profile
        @impact_studio.enter_profile_desc 'This is not what I mean!'
        @impact_studio.cancel_profile_edit
        @impact_studio.wait_until { @impact_studio.profile_desc == desc }
      end

      it 'allows the user to include a link in a description' do
        @impact_studio.edit_profile "My personal description includes a link to #{link = 'www.google.com'} !"
        @impact_studio.wait_until { @impact_studio.profile_desc.include? 'My personal description includes a link to' }
        expect(@impact_studio.external_link_valid?(@driver, @impact_studio.link_element(xpath: "//a[contains(.,'#{link}')]"), 'Google'))
      end

      it 'allows the user to include a hashtag in a description' do
        @impact_studio.switch_to_canvas_iframe @driver
        @impact_studio.edit_profile 'My personal description #BitterTogether'
        @impact_studio.wait_until { @impact_studio.profile_desc.include? 'My personal description ' }
        @impact_studio.link_element(text: '#BitterTogether').click
        @asset_library.wait_until(Utils.short_wait) { @asset_library.title == 'Asset Library' }
        @asset_library.switch_to_canvas_iframe @driver
        @asset_library.no_search_results_element.when_visible Utils.short_wait
      end

      it 'allows the user to add a maximum of X characters to a description' do
        @impact_studio.load_page(@driver, @impact_studio_url)
        @impact_studio.click_edit_profile
        @impact_studio.enter_profile_desc (desc = "#{'A loooooong title' * 15}?")
        @impact_studio.char_limit_msg_element.when_visible 1
        @impact_studio.cancel_profile_edit
        @impact_studio.edit_profile (desc = desc[0, 255])
        @impact_studio.wait_until { @impact_studio.profile_desc == desc }
      end

      it 'allows the user to remove a description' do
        @impact_studio.edit_profile ''
        sleep 1
        @impact_studio.profile_desc_element.when_not_visible Utils.short_wait
      end
    end
  end

  describe 'search' do

    users.each do |user|
      it("allows the user to view #{user.role} UID #{user.uid}'s profile") { @impact_studio.search_for_user user }
    end

  end
end
