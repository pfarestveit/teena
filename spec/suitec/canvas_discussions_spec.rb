require_relative '../../util/spec_helper'

describe 'A Canvas discussion', order: :defined do

  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id
  test_user_data = Utils.load_suitec_test_data.select { |data| data['tests']['canvas_discussions'] }

  add_topic = Activity::ADD_DISCUSSION_TOPIC
  add_entry = Activity::ADD_DISCUSSION_ENTRY
  get_reply = Activity::GET_DISCUSSION_REPLY

  before(:all) do
    @course = Course.new({})
    @course.site_id = course_id
    @user_1 = User.new test_user_data[0]
    @user_2 = User.new test_user_data[1]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasActivitiesPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    # Create test course site. If using an existing site, include the Asset Library and ensure Canvas sync is enabled.
    tools = [SuiteCTools::ENGAGEMENT_INDEX]
    tools << SuiteCTools::ASSET_LIBRARY unless course_id.nil?
    @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@user_1, @user_2], test_id, tools)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)
    unless course_id.nil?
      @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
      @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
      @asset_library.ensure_canvas_sync(@driver, @asset_library_url)
    end

    # Get current score
    @engagement_index.load_scores(@driver, @engagement_index_url)
    @user_1_score = @engagement_index.user_score @user_1

    # User 1 creates a discussion topic, which should earn points
    @discussion = Discussion.new "Discussion Topic #{test_id}"
    @canvas.log_out(@driver, @cal_net)
    @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password)
    @canvas.create_course_discussion(@driver, @course, @discussion)
    @user_1_expected_score = "#{@user_1_score.to_i + add_topic.points}"
  end

  after(:all) { @driver.quit }

  it "earns '#{add_topic.title}' Engagement Index points for the discussion creator" do
    expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_1, @user_1_expected_score)).to be true
  end

  it "adds '#{add_topic.type}' activity to the CSV export for the discussion creator" do
    scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
    expect(scores).to include("#{@user_1.full_name}, #{add_topic.type}, #{add_topic.points}, #{@user_1_expected_score}")
  end

  describe 'entry' do

    before(:all) do
      # Get current scores
      @engagement_index.load_page(@driver, @engagement_index_url)
      @user_1_score = @engagement_index.user_score @user_1
      @user_2_score = @engagement_index.user_score @user_2

      # User 1 creates an entry on the topic, which should earn no points
      @canvas.add_reply(@discussion, nil, 'Discussion entry by the discussion topic creator')

      # User 2 creates an entry on the topic, which should earn points for User 2 only
      @canvas.log_out(@driver, @cal_net)
      @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
      @canvas.load_course_site(@driver, @course)
      @canvas.add_reply(@discussion, nil, 'Discussion entry by someone other than the discussion topic creator')
      @user_2_expected_score = "#{@user_2_score.to_i + add_entry.points}"
    end

    context 'when added by someone other than the discussion topic creator' do

      it "earns '#{add_entry.title}' Engagement Index points for the user adding the entry" do
        expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_2, @user_2_expected_score)).to be true
      end

      it('earns no points for the discussion topic creator') { expect(@engagement_index.user_score @user_1).to eql(@user_1_score) }

      it 'adds "discussion_entry" activity to the CSV export for the user adding the entry' do
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
        expect(scores).to include("#{@user_2.full_name}, #{add_entry.type}, #{add_entry.points}, #{@user_2_expected_score}")
      end
    end

    context 'when added by the discussion topic creator' do

      it("earns no '#{add_entry.title}' Engagement Index points for the user adding the entry") { expect(@engagement_index.user_score @user_1).to eql(@user_1_score) }

      it "adds no '#{add_entry.type}' activity to the CSV export for the discussion creator" do
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
        expect(scores).not_to include("#{@user_1.full_name}, #{add_entry.type}, #{add_entry.points}, #{@user_1_score.to_i + add_entry.points}")
      end
    end

    context 'when added by someone who has already added an earlier discussion entry' do

      before(:all) do
        # Get current scores
        @engagement_index.load_page(@driver, @engagement_index_url)
        @user_1_score = @engagement_index.user_score @user_1
        @user_2_score = @engagement_index.user_score @user_2

        # User 2 replies to the topic again, which should earn points for User 2 only
        @canvas.add_reply(@discussion, nil, 'Discussion entry by somebody other than the discussion topic creator')
        @user_2_expected_score = "#{@user_2_expected_score.to_i + add_entry.points}"
      end

      it "earns '#{add_entry.title}' Engagement Index points for the user adding the entry" do
        expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_2, @user_2_expected_score)).to be true
      end

      it('earns no points for the discussion topic creator') { expect(@engagement_index.user_score @user_1).to eql(@user_1_score) }

      it 'adds "discussion_entry" activity to the CSV export for the user adding the entry' do
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
        expect(scores).to include("#{@user_2.full_name}, #{add_entry.type}, #{add_entry.points}, #{@user_2_expected_score}")
      end
    end
  end

  describe 'entry reply' do

    context 'when added by someone' do

      before(:all) do
        # Get current scores
        @engagement_index.load_page(@driver, @engagement_index_url)
        @user_1_score = @engagement_index.user_score @user_1
        @user_2_score = @engagement_index.user_score @user_2

        # User 1 replies to own entry, which should earn no points
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password)
        @canvas.add_reply(@discussion, 0, 'Reply by the discussion topic creator and also the discussion entry creator')

        # User 1 replies to User 2's first entry, which should earn points for both
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password)
        @canvas.add_reply(@discussion, 2, 'Reply by the discussion topic creator but not the discussion entry creator')
        @user_1_expected_score = "#{@user_1_score.to_i + add_entry.points}"
        @user_2_expected_score = "#{@user_2_score.to_i + get_reply.points}"
      end

      context 'who created the discussion topic but not the discussion entry' do

        it "earns '#{add_entry.title}' Engagement Index points for the user who added the discussion entry reply" do
          expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_1, @user_1_expected_score)).to be true
        end

        it "earns '#{get_reply.title}' Engagement Index points for the user who received the discussion entry reply" do
          expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_2, @user_2_expected_score)).to be true
        end

        it "adds '#{add_entry.title}' and '#{get_reply.type}' activity to the CSV export for the users" do
          scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
          expect(scores).to include("#{@user_1.full_name}, #{add_entry.type}, #{add_entry.points}, #{@user_1_expected_score}")
          expect(scores).to include("#{@user_2.full_name}, #{get_reply.type}, #{get_reply.points}, #{@user_2_expected_score}")
        end
      end

      context 'when added by someone who created the discussion topic and the discussion entry' do

        it('earns no Engagement Index points for the user') { expect(@engagement_index.user_score @user_1).to eql(@user_1_expected_score) }

      end
    end

    context 'when added by someone' do

      before(:all) do
        # Get current scores
        @engagement_index.load_page(@driver, @engagement_index_url)
        @user_1_score = @engagement_index.user_score @user_1
        @user_2_score = @engagement_index.user_score @user_2

        # User 2 replies to own first entry, which should earn no points
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
        @canvas.add_reply(@discussion, 2, 'Reply by somebody other than the discussion topic creator but who is the discussion entry creator')

        # User 2 replies to User 1's entry, which should earn points for both
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
        @canvas.add_reply(@discussion, 0, 'Reply by somebody other than the discussion topic creator and other than the discussion entry creator')
        @user_1_expected_score = "#{@user_1_score.to_i + get_reply.points}"
        @user_2_expected_score = "#{@user_2_score.to_i + add_entry.points}"
      end

      context 'who did not create the discussion topic or the discussion entry' do

        it "earns '#{get_reply.title}' Engagement Index points for the user who received the discussion entry reply" do
          expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_1, @user_1_expected_score)).to be true
        end

        it "earns '#{add_entry.title}' Engagement Index points for the user who added the discussion entry reply" do
          expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_2, @user_2_expected_score)).to be true
        end

        it "adds '#{add_entry.title}' and '#{get_reply.type}' activity to the CSV export for the users" do
          scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
          expect(scores).to include("#{@user_1.full_name}, #{get_reply.type}, #{get_reply.points}, #{@user_1_expected_score}")
          expect(scores).to include("#{@user_2.full_name}, #{add_entry.type}, #{add_entry.points}, #{@user_2_expected_score}")
        end
      end

      context 'who did not create the discussion topic but did create the discussion entry' do

        it('earns no Engagement Index points for the user') { expect(@engagement_index.user_score @user_2).to eql(@user_2_expected_score) }

      end

    end

    context 'when added by someone' do

      before(:all) do
        # Get current scores
        @engagement_index.load_page(@driver, @engagement_index_url)
        @user_1_score = @engagement_index.user_score @user_1
        @user_2_score = @engagement_index.user_score @user_2

        # User 2 replies to own first entry, which should earn no points
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
        @canvas.add_reply(@discussion, 3, 'Reply by somebody other than the discussion topic creator but who is the discussion entry creator')

        # User 2 replies again to User 1's reply, which should earn points for both
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
        @canvas.add_reply(@discussion, 0, 'Reply by somebody other than the discussion topic creator and other than the discussion entry creator')
        @user_1_expected_score = "#{@user_1_score.to_i + get_reply.points}"
        @user_2_expected_score = "#{@user_2_score.to_i + add_entry.points}"
      end

      context 'who did not create the discussion topic but did create the discussion entry' do

        it "earns '#{get_reply.title}' Engagement Index points for the user who received the discussion entry reply" do
          expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_1, @user_1_expected_score)).to be true
        end

        it "earns '#{add_entry.title}' Engagement Index points for the user who added the discussion entry reply" do
          expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_2, @user_2_expected_score)).to be true
        end

        it "adds '#{add_entry.title}' and '#{get_reply.type}' activity to the CSV export for the users" do
          scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
          expect(scores).to include("#{@user_1.full_name}, #{get_reply.type}, #{get_reply.points}, #{@user_1_expected_score}")
          expect(scores).to include("#{@user_2.full_name}, #{add_entry.type}, #{add_entry.points}, #{@user_2_expected_score}")
        end
      end

      context 'who added an earlier discussion entry reply' do

        it('earns no Engagement Index points for the user') { expect(@engagement_index.user_score @user_2).to eql(@user_2_expected_score) }

      end
    end
  end

  describe 'reply to reply' do

    context 'when added by someone' do

      before(:all) do
        # Get current scores
        @engagement_index.load_page(@driver, @engagement_index_url)
        @user_1_score = @engagement_index.user_score @user_1
        @user_2_score = @engagement_index.user_score @user_2

        # User 2 replies to its own first reply to User 1's entry, which should earn no points
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
        @canvas.add_reply(@discussion, 2, 'Reply-to-reply by somebody who created the reply but not the topic or the entry')

        # User 1 replies to User 2's first reply to User 1's entry, which should earn points for both
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password)
        @canvas.add_reply(@discussion, 2, 'Reply-to-reply by somebody who created the topic and the entry but not the reply')

        # Determine expected scores
        @user_1_expected_score = "#{@user_1_score.to_i + add_entry.points}"
        @user_2_expected_score = "#{@user_2_score.to_i + get_reply.points}"
      end

      context 'who created the entry but not the reply' do

        it "earns '#{add_entry.title}' Engagement Index points for the user who added the reply to reply" do
          expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_1, @user_1_expected_score)).to be true
        end

        it "earns '#{get_reply.title}' Engagement Index points for the user who received the reply to reply" do
          expect(@engagement_index.user_score_updated?(@driver, @engagement_index_url, @user_2, @user_2_expected_score)).to be true
        end

        it "adds '#{add_entry.title}' and '#{get_reply.type}' activity to the CSV export for the users" do
          scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
          expect(scores).to include("#{@user_1.full_name}, #{add_entry.type}, #{add_entry.points}, #{@user_1_expected_score}")
          expect(scores).to include("#{@user_2.full_name}, #{get_reply.type}, #{get_reply.points}, #{@user_2_expected_score}")
        end
      end

      context 'who created the reply but not the entry' do

        it('earns no Engagement Index points for the user') { expect(@engagement_index.user_score @user_2).to eql(@user_2_expected_score) }

      end
    end
  end
end
