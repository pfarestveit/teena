require_relative '../../util/spec_helper'

describe 'Impact Studio' do

  test = SquiggyTestConfig.new 'profile_search'
  teacher = test.course.teachers[0]
  student_1 = test.course.students[0]
  student_2 = test.course.students[1]

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when there are fewer than two members of the course site' do

    context 'and the course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(teacher, test.course)
        @impact_studio.load_page test
      end

      it('offers no user search field') { expect(@impact_studio.search_input?).to be false }
      it 'offers no user profile pagination' do
        expect(@impact_studio.browse_previous?).to be false
        expect(@impact_studio.browse_next?).to be false
      end
    end

    context 'and an non-member admin views its profile' do

      before(:all) do
        @canvas.stop_masquerading
        @impact_studio.load_page test
      end

      it('offers no user search field') { expect(@impact_studio.search_input?).to be false }
      it 'offers no user profile pagination' do
        expect(@impact_studio.browse_previous?).to be false
        expect(@impact_studio.browse_next?).to be false
      end
    end
  end

  context 'when there are exactly two members of the course site' do

    before(:all) { @canvas.add_users(test.course, [student_1]) }

    context 'and a course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(student_1, test.course)
        @impact_studio.load_page test
      end

      it('offers a user search field') { expect(@impact_studio.search_input?).to be false }
      it 'offers "next user" pagination only' do
        expect(@impact_studio.browse_previous?).to be false
        expect(@impact_studio.browse_next?).to be true
      end
    end

    context 'and a course site admin views its profile' do

      before(:all) do
        @canvas.masquerade_as teacher
        @impact_studio.load_page test
      end

      it('offers a user search field') { expect(@impact_studio.search_input?).to be false }
      it 'offers "previous user" and "next user" pagination' do
        expect(@impact_studio.browse_previous?).to be true
        expect(@impact_studio.browse_next?).to be true
      end
    end
  end

  context 'when there are more than two members of the course site' do

    before(:all) do
      @canvas.add_users(test.course, students.drop(1))
      @engagement_index.wait_for_new_user_sync(test, students)
    end

    context 'and a course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(student_2, test.course)
        @impact_studio.load_page test
      end

      it('offers a user search field') { expect(@impact_studio.search_input?).to be true }
      it 'offers "previous user" and "next user" pagination' do
        expect(@impact_studio.browse_previous?).to be true
        expect(@impact_studio.browse_next?).to be true
      end
    end
  end

  describe 'search' do

    before(:all) do
      @canvas.masquerade_as(teacher, test.course)
      @impact_studio.load_page test
    end

    students.each do |student|
      it("allows the user to view UID #{student.uid}'s profile") { @impact_studio.select_user student }
    end
  end

  describe 'pagination' do

    before(:all) do
      @canvas.masquerade_as student_1
      @impact_studio.load_page test
    end

    it 'allows the user to page next through each course site member' do
      users = test.course.roster
      users.sort_by! { |u| u.full_name }
      index_of_current_user = users.index student_1
      users.rotate!(index_of_current_user + 1)
      users.each { |user| @impact_studio.browse_next_user user }
    end

    it 'allows the user to page previous through each course site member' do
      users = test.course.roster
      users.reverse!
      index_of_current_user = users.index(student_1)
      users.rotate!(index_of_current_user + 1)
      users.each { |user| @impact_studio.browse_previous_user user }
    end
  end
end
