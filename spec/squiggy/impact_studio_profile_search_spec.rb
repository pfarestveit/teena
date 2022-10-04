require_relative '../../util/spec_helper'

describe 'Impact Studio' do

  test = SquiggyTestConfig.new 'profile_search'
  teacher = test.teachers[0]
  student_1 = test.students[0]
  student_2 = test.students[1]
  students = [student_1, student_2]
  test.course.roster -= students

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when there are fewer than two members of the course site' do

    context 'and the course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(teacher, test.course)
        @impact_studio.load_own_profile(test, teacher)
      end

      it 'offers a user search field' do
        @impact_studio.user_select_element.when_present Utils.short_wait
        expect(@impact_studio.user_select_options.map &:strip).to eql([teacher.full_name])
      end
      it 'offers user profile pagination' do
        expect(@impact_studio.browse_previous_element.text).to include(teacher.full_name)
        expect(@impact_studio.browse_next_element.text).to include(teacher.full_name)
      end
    end
  end

  context 'when there are exactly two members of the course site' do

    before(:all) do
      @canvas.stop_masquerading
      @canvas.add_users(test.course, [student_1])
    end

    context 'and a course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(student_1, test.course)
        @impact_studio.load_own_profile(test, student_1)
      end

      it 'offers a user search field' do
        @impact_studio.user_select_element.when_present Utils.short_wait
        expect(@impact_studio.user_select_options.map &:strip).to eql([teacher.full_name, student_1.full_name])
      end
      it 'offers user profile pagination' do
        expect(@impact_studio.browse_previous_element.text).to include(teacher.full_name)
        expect(@impact_studio.browse_next_element.text).to include(teacher.full_name)
      end
    end
  end

  context 'when there are more than two members of the course site' do

    before(:all) do
      @canvas.stop_masquerading
      @canvas.add_users(test.course, students.drop(1))
    end

    context 'and a course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(student_2, test.course)
        @impact_studio.load_own_profile(test, student_2)
      end

      it 'offers a user search field' do
        @impact_studio.user_select_element.when_present Utils.short_wait
        expect(@impact_studio.user_select_options.map &:strip).to eql([teacher.full_name, student_1.full_name, student_2.full_name])
      end
      it 'offers user profile pagination' do
        expect(@impact_studio.browse_previous_element.text).to include(student_1.full_name)
        expect(@impact_studio.browse_next_element.text).to include(teacher.full_name)
      end
    end
  end

  describe 'search' do

    before(:all) do
      @canvas.masquerade_as(teacher, test.course)
      @impact_studio.load_own_profile(test, teacher)
    end

    students.each do |student|
      it "allows the user to view UID #{student.uid}'s profile" do
        @impact_studio.select_user student
        @impact_studio.wait_for_profile student
      end
    end
  end

  describe 'pagination' do

    before(:all) do
      @users = [teacher, student_1, student_2]
      @canvas.masquerade_as student_1
      @impact_studio.load_own_profile(test, student_1)
    end

    it 'allows the user to page next through each course site member' do
      @users.sort_by! { |u| u.full_name }
      index_of_current_user = @users.index student_1
      @users.rotate!(index_of_current_user + 1)
      @users.each { |user| @impact_studio.browse_next_user user }
    end

    it 'allows the user to page previous through each course site member' do
      @users.reverse!
      index_of_current_user = @users.index(student_1)
      @users.rotate!(index_of_current_user + 1)
      @users.each { |user| @impact_studio.browse_previous_user user }
    end
  end
end
