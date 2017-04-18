require_relative '../../util/spec_helper'

describe 'Impact Studio' do

  include Logging
  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id

  # Get test users
  user_test_data = Utils.load_test_users.select { |data| data['tests']['assetLibraryCategorySearch'] }
  users = user_test_data.map { |data| User.new(data) if ['Teacher', 'Designer', 'Lead TA', 'TA', 'Observer', 'Reader', 'Student'].include? data['role'] }

  teachers = users.select { |user| user.role == 'Teacher' }
  teacher_viewer = teachers[0]
  teacher_share = teachers[1]
  teacher_no_share = users.find { |user| user.role = 'TA' }

  students = users.select { |user| user.role == 'Student' }
  student_viewer = students[0]
  student_share = students[1]
  student_no_share = students[2]

  before(:all) do
    @course = Course.new({})
    @course.site_id = course_id

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @impact_studio = Page::SuiteCPages::ImpactStudioPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    # Create course site if necessary
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::IMPACT_STUDIO])
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @impact_studio_url = @canvas.click_tool_link(@driver, SuiteCTools::IMPACT_STUDIO)

    @canvas.masquerade_as(@driver, student_viewer, @course)
    @impact_studio.load_page(@driver, @impact_studio_url)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'profile summary' do

    it('shows the user name') { expect(@impact_studio.name).to eql(student_viewer.full_name) }
    it('shows the user avatar') { expect(@impact_studio.avatar?).to be true }
    it('shows an Edit Profile link') { expect(@impact_studio.edit_profile_link?).to be true }

    describe 'location' do

      context 'when the user has no location' do
        it('shows no location')
      end

      context 'when the user has a location' do
        it('shows the location')
      end
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

      context 'when the user has no description' do
        it('allows the user to add a description')
        it('allows the user to include a link in a description')
        it('allows the user to add a maximum of X characters to a description')
      end

      context 'when the user has a description' do
        it('shows the description')
        it('allows the user to edit a description')
        it('allows the user to include a link in an edited description')
        it('allows the user to add a maximum of X characters to an edited description')
        it('allows the user to remove a description')
      end
    end

    describe 'hashtags' do

      context 'when the user has no hashtags' do
        it('shows no hashtags')
        it('allows the user to add hashtags')
        it('allows the user to include special characters in a hashtag')
        it('allows the user to add X hashtags')
      end

      context 'when the user has hashtags' do
        it('shows the hashtags')
        it('allows the user to edit hashtags')
        it('allows the user to remove hashtags')
      end

      context 'when clicked' do
        it('shows users also associated with the same hashtag')
        it('shows assets also associated with the same hashtag')
      end
    end
  end

  describe 'search'

  describe 'Engagement Index card' do

    context 'when the Engagement Index is not present' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @canvas.disable_tool(@course, SuiteCTools::ENGAGEMENT_INDEX)
      end

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

          before(:all) do
            # TODO - search for user in Impact Studio, load profile
            sleep 3
          end

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

          before(:all) do
            # TODO - search for user in Impact Studio, load profile
            sleep 3
          end

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
          before(:all) do
            # TODO - search for user in Impact Studio, load profile
            sleep 3
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of an instructor who has shared its score' do
          before(:all) do
            # TODO - search for user in Impact Studio, load profile
            sleep 3
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of a student who has not shared its score' do
          before(:all) do
            # TODO - search for user in Impact Studio, load profile
            sleep 3
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
        end

        context 'views the Impact Studio profile of a student who has shared its score' do
          before(:all) do
            # TODO - search for user in Impact Studio, load profile
            sleep 3
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
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
          before(:all) do
            # TODO - search for user in Impact Studio, load profile
            sleep 3
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
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
            # TODO - search for user in Impact Studio, load profile
            sleep 3
          end

          it('shows an Engagement Index link') { @impact_studio.engagement_index_link_element.when_visible 3 }
          it('shows no score') { expect(@impact_studio.engagement_index_score?).to be false }
          it('shows no "turn on" sharing link') { expect(@impact_studio.turn_on_sharing_link?).to be false }
          it('shows no rank') { expect(@impact_studio.engagement_index_rank?).to be false }
          it('shows no rank total') { expect(@impact_studio.engagement_index_rank_ttl?).to be false }
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
    end
  end
end
