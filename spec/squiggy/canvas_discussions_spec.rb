require_relative '../../util/spec_helper'

describe 'A Canvas discussion' do

  add_topic = SquiggyActivity::ADD_DISCUSSION_TOPIC
  add_entry = SquiggyActivity::ADD_DISCUSSION_ENTRY
  get_reply = SquiggyActivity::GET_DISCUSSION_REPLY

  before(:all) do
    @test = SquiggyTestConfig.new 'canvas_discussions'
    @test.course.site_id = ENV['COURSE_ID']
    @user_0 = @test.teachers[0]
    @user_1 = @test.teachers[1]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasAnnounceDiscussPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @engagement_index.wait_for_new_user_sync(@test, [@user_0, @user_1])
    @user_0.score = @engagement_index.user_score(@test, @user_0)
    @user_1.score = @engagement_index.user_score(@test, @user_1)

    @discussion = Discussion.new "#{@test.course.title} Discussion"
    @canvas.masquerade_as @user_0
    @canvas.create_course_discussion(@test.course, @discussion)
    @user_0_expected_score = @user_0.score + add_topic.points
  end

  after(:all) { @driver.quit }

  it 'earns Discussion Topic Engagement Index points for the discussion creator' do
    expect(@engagement_index.user_score_updated?(@test, @user_0, @user_0_expected_score)).to be true
  end

  it 'adds discussion-topic activity to the CSV export for the discussion creator' do
    activity = @engagement_index.download_csv(@test).find do |r|
      r[:user_name] == @user_0.full_name &&
        r[:action] == add_topic.type &&
        r[:score] == add_topic.points &&
        r[:running_total] == @user_0.score
    end
    expect(activity).to be_truthy
  end

  describe 'entry' do

    context 'when added' do

      before(:all) do
        # User 0 creates an entry on the topic, which should earn no points
        @canvas.add_reply(@discussion, nil, 'Discussion entry by the discussion topic creator')

        # User 1 creates an entry on the topic, which should earn points for User 1 only
        @canvas.masquerade_as(@user_1, @test.course)
        @canvas.add_reply(@discussion, nil, 'Discussion entry by someone other than the discussion topic creator')
        @user_1_expected_score = @user_1.score + add_entry.points
      end

      context 'by someone other than the discussion topic creator' do

        it 'earns Discussion Entry Engagement Index points for the user adding the entry' do
          expect(@engagement_index.user_score_updated?(@test, @user_1, @user_1_expected_score)).to be true
        end

        it 'earns no points for the discussion topic creator' do
          expect(@engagement_index.user_score(@test, @user_0)).to eql(@user_0.score)
        end

        it 'adds discussion-entry activity to the CSV export for the user adding the entry' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_1.full_name &&
              r[:action] == add_entry.type &&
              r[:score] == add_entry.points &&
              r[:running_total] == @user_1.score
          end
          expect(activity).to be_truthy
        end
      end

      context 'by the discussion topic creator' do

        it 'earns no Discussion Entry Engagement Index points for the user adding the entry' do
          expect(@engagement_index.user_score(@test, @user_0)).to eql(@user_0.score)
        end

        it 'adds no discussion-entry activity to the CSV export for the discussion creator' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_0.full_name &&
              r[:action] == add_entry.type &&
              r[:score] == add_entry.points &&
              r[:running_total] == (@user_0.score + add_entry.points)
          end
          expect(activity).to be_falsey
        end
      end
    end

    context 'when added' do

      before(:all) do
        # User 1 replies to the topic again, which should earn points for User 1 only
        @canvas.add_reply(@discussion, nil, 'Discussion entry by somebody other than the discussion topic creator')
        @user_1_expected_score = @user_1.score + add_entry.points
      end

      context 'by someone who has already added an earlier discussion entry' do

        it 'earns Discussion Entry Engagement Index points for the user adding the entry' do
          expect(@engagement_index.user_score_updated?(@test, @user_1, @user_1_expected_score)).to be true
        end

        it 'earns no points for the discussion topic creator' do
          expect(@engagement_index.user_score(@test, @user_0)).to eql(@user_0.score)
        end

        it 'adds discussion-entry activity to the CSV export for the user adding the entry' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_1.full_name &&
              r[:action] == add_entry.type &&
              r[:score] == add_entry.points &&
              r[:running_total] == @user_1.score
          end
          expect(activity).to be_truthy
        end
      end
    end
  end

  describe 'entry reply' do

    context 'when added' do

      before(:all) do
        # User 0 replies to own entry, which should earn no points
        @canvas.masquerade_as @user_0
        @canvas.add_reply(@discussion, 0, 'Reply by the discussion topic creator and also the discussion entry creator')

        # User 0 replies to User 1's first entry, which should earn points for both
        @canvas.add_reply(@discussion, 2, 'Reply by the discussion topic creator but not the discussion entry creator')
        @user_0_expected_score = @user_0.score + add_entry.points
        @user_1_expected_score = @user_1.score + get_reply.points
      end

      context 'by someone who created the discussion topic but not the discussion entry' do

        it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply' do
          expect(@engagement_index.user_score_updated?(@test, @user_0, @user_0_expected_score)).to be true
        end

        it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply' do
          expect(@engagement_index.user_score_updated?(@test, @user_1, @user_1_expected_score)).to be true
        end

        it 'adds discussion-entry activity to the CSV export for the entry reply' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_0.full_name &&
              r[:action] == add_entry.type &&
              r[:score] == add_entry.points &&
              r[:running_total] == @user_0.score
          end
          expect(activity).to be_truthy
        end

        it 'adds discussion-reply activity to the CSV export for the entry reply' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_1.full_name &&
              r[:action] == get_reply.type &&
              r[:score] == get_reply.points &&
              r[:running_total] == @user_1.score
          end
          expect(activity).to be_truthy
        end
      end

      context 'by someone who created the discussion topic and the discussion entry' do

        it 'earns no Engagement Index points for the user' do
          expect(@engagement_index.user_score(@test, @user_0)).to eql(@user_0.score)
        end
      end
    end

    context 'when added' do

      before(:all) do
        # User 1 replies to own first entry, which should earn no points
        @canvas.masquerade_as @user_1
        @canvas.add_reply(@discussion, 2, 'Reply by somebody other than the discussion topic creator but who is the discussion entry creator')

        # User 1 replies to User 0's entry, which should earn points for both
        @canvas.add_reply(@discussion, 0, 'Reply by somebody other than the discussion topic creator and other than the discussion entry creator')
        @user_1_expected_score = @user_1.score + add_entry.points
        @user_0_expected_score = @user_0.score + get_reply.points
      end

      context 'by someone who did not create the discussion topic or the discussion entry' do

        it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply' do
          expect(@engagement_index.user_score_updated?(@test, @user_0, @user_0_expected_score)).to be true
        end

        it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply' do
          expect(@engagement_index.user_score_updated?(@test, @user_1, @user_1_expected_score)).to be true
        end

        it 'adds discussion-reply activity to the CSV export fort the user who received the discussion entry reply' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_0.full_name &&
              r[:action] == get_reply.type &&
              r[:score] == get_reply.points &&
              r[:running_total] == @user_0.score
          end
          expect(activity).to be_truthy
        end

        it 'adds discussion-entry activity to the CSV export for the user who added the discussion entry reply' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_1.full_name &&
              r[:action] == add_entry.type &&
              r[:score] == add_entry.points &&
              r[:running_total] == @user_1.score
          end
          expect(activity).to be_truthy
        end
      end

      context 'by someone who did not create the discussion topic but did create the discussion entry' do

        it 'earns no Engagement Index points for the user' do
          expect(@engagement_index.user_score(@test, @user_1)).to eql(@user_1.score)
        end
      end
    end

    context 'when added' do

      before(:all) do
        # User 1 replies to own first entry, which should earn no points
        @canvas.add_reply(@discussion, 3, 'Reply by somebody other than the discussion topic creator but who is the discussion entry creator')

        # User 1 replies again to User 0's reply, which should earn points for both
        @canvas.add_reply(@discussion, 0, 'Second reply by somebody other than the discussion topic creator and other than the discussion entry creator')
        @user_1_expected_score = @user_1.score + add_entry.points
        @user_0_expected_score = @user_0.score + get_reply.points
      end

      context 'by someone who did not create the discussion topic but did create the discussion entry' do

        it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply' do
          expect(@engagement_index.user_score_updated?(@test, @user_0, @user_0_expected_score)).to be true
        end

        it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply' do
          expect(@engagement_index.user_score_updated?(@test, @user_1, @user_1_expected_score)).to be true
        end

        it 'adds discussion-entry activity to the CSV export for the user who received the discussion entry reply' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_0.full_name &&
              r[:action] == get_reply.type &&
              r[:score] == get_reply.points &&
              r[:running_total] == @user_0.score
          end
          expect(activity).to be_truthy
        end

        it 'adds discussion-reply activity to the CSV export for the user who added the discussion entry reply' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_1.full_name &&
              r[:action] == add_entry.type &&
              r[:score] == add_entry.points &&
              r[:running_total] == @user_1.score
          end
          expect(activity).to be_truthy
        end
      end

      context 'by someone who added an earlier discussion entry reply' do

        it 'earns no Engagement Index points for the user' do
          expect(@engagement_index.user_score(@test, @user_1)).to eql(@user_1.score)
        end
      end
    end
  end

  describe 'reply to reply' do

    context 'when added' do

      before(:all) do
        # User 1 replies to its own first reply to User 0's entry, which should earn no points
        @canvas.add_reply(@discussion, 2, 'Reply-to-reply by somebody who created the reply but not the topic or the entry')

        # User 0 replies to User 1's first reply to User 1's entry, which should earn points for both
        @canvas.masquerade_as @user_0
        @canvas.add_reply(@discussion, 2, 'Reply-to-reply by somebody who created the topic and the entry but not the reply')
        @user_0_expected_score = @user_0.score + add_entry.points
        @user_1_expected_score = @user_1.score + get_reply.points
      end

      context 'by someone who created the entry but not the reply' do

        it 'earns Discussion Entry Engagement Index points for the user who added the reply to reply' do
          expect(@engagement_index.user_score_updated?(@test, @user_0, @user_0_expected_score)).to be true
        end

        it 'earns Discussion Reply Engagement Index points for the user who received the reply to reply' do
          expect(@engagement_index.user_score_updated?(@test, @user_1, @user_1_expected_score)).to be true
        end

        it 'adds discussion-entry activity to the CSV export for the user added the reply to reply' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_0.full_name &&
              r[:action] == add_entry.type &&
              r[:score] == add_entry.points &&
              r[:running_total] == @user_0.score
          end
          expect(activity).to be_truthy
        end

        it 'adds discussion-reply activity to the CSV export for the user who received the reply to reply' do
          activity = @engagement_index.download_csv(@test).find do |r|
            r[:user_name] == @user_1.full_name &&
              r[:action] == get_reply.type &&
              r[:score] == get_reply.points &&
              r[:running_total] == @user_1.score
          end
          expect(activity).to be_truthy
        end
      end

      context 'by someone who created the reply but not the entry' do

        it 'earns no Engagement Index points for the user' do
          expect(@engagement_index.user_score(@test, @user_1)).to eql(@user_1.score)
        end
      end
    end
  end
end
