require_relative '../../util/spec_helper'

describe 'Impact Studio', order: :defined do

  include Logging
  test_id = Utils.get_test_id

  # Get test users
  user_test_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['impact_studio_assets'] }
  users = user_test_data.map { |data| User.new(data) if %w(Teacher Student).include? data['role'] }
  teacher = users.find { |user| user.role == 'Teacher' }
  students = users.select { |user| user.role == 'Student' }
  student_1 = students[0]
  student_2 = students[1]

  before(:all) do
    @course = Course.new({title: "Impact Studio Search #{test_id}", code: "Impact Studio Search #{test_id}"})

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver
    @impact_studio = Page::SuiteCPages::ImpactStudioPage.new @driver

    # Create course site with only the teacher as member initially
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [teacher], test_id,
                                       [LtiTools::ENGAGEMENT_INDEX, LtiTools::IMPACT_STUDIO])
    @engagement_index_url = @canvas.click_tool_link(@driver, LtiTools::ENGAGEMENT_INDEX)
    @impact_studio_url = @canvas.click_tool_link(@driver, LtiTools::IMPACT_STUDIO)
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when there are fewer than two members of the course site' do

    context 'and the course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(@driver, teacher, @course)
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('offers no user search field') { expect(@impact_studio.search_input?).to be false }
      it('offers no user profile pagination') do
        expect(@impact_studio.browse_previous?).to be false
        expect(@impact_studio.browse_next?).to be false
      end
    end

    context 'and an non-member admin views its profile' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('offers no user search field') { expect(@impact_studio.search_input?).to be false }
      it('offers no user profile pagination') do
        expect(@impact_studio.browse_previous?).to be false
        expect(@impact_studio.browse_next?).to be false
      end
    end
  end

  context 'when there are exactly two members of the course site' do

    before(:all) { @canvas.add_users(@course, [student_1]) }

    context 'and a course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_1, @course)
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('offers a user search field') { expect(@impact_studio.search_input?).to be false }
      it('offers "next user" pagination only') do
        expect(@impact_studio.browse_previous?).to be false
        expect(@impact_studio.browse_next?).to be true
      end
    end

    context 'and a course site admin views its profile' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('offers a user search field') { expect(@impact_studio.search_input?).to be false }
      it('offers "previous user" and "next user" pagination') do
        expect(@impact_studio.browse_previous?).to be true
        expect(@impact_studio.browse_next?).to be true
      end
    end
  end

  context 'when there are more than two members of the course site' do

    before(:all) do
      @canvas.add_users(@course, students.drop(1))
      @engagement_index.wait_for_new_user_sync(@driver, @engagement_index_url, students)
    end

    context 'and a course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_2, @course)
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('offers a user search field') { expect(@impact_studio.search_input?).to be true }
      it('offers "previous user" and "next user" pagination') do
        expect(@impact_studio.browse_previous?).to be true
        expect(@impact_studio.browse_next?).to be true
      end
    end
  end

  describe 'search ' do

    before(:all) do
      @canvas.masquerade_as(@driver, teacher, @course)
      @impact_studio.load_page(@driver, @impact_studio_url)
    end

    students.each do |student|
      it("allows the user to view UID #{student.uid}'s profile") { @impact_studio.search_for_user student }
    end
  end

  describe 'pagination' do

    before(:all) do
      @canvas.masquerade_as(@driver, student_1, @course)
      @impact_studio.load_page(@driver, @impact_studio_url)
    end

    it 'allows the user to page next through each course site member' do
      users.sort_by! { |u| u.full_name }
      index_of_current_user = users.index(student_1)
      users.rotate!(index_of_current_user + 1)
      users.each { |user| @impact_studio.browse_next_user user }
    end

    it 'allows the user to page previous through each course site member' do
      users.reverse!
      index_of_current_user = users.index(student_1)
      users.rotate!(index_of_current_user + 1)
      users.each { |user| @impact_studio.browse_previous_user user }
    end
  end
end
