class TestConfig

  attr_accessor :id,
                :test_course_data,
                :test_user_data,
                :admin,
                :designer,
                :lead_ta,
                :observer,
                :reader,
                :staff,
                :students,
                :ta,
                :teachers,
                :wait_list_student

  # Sets a unique ID (the epoch) for a test run
  def initialize(test_name = nil)
    @id = "QA Test #{Time.now.to_i}"
    @admin = User.new uid: Utils.super_admin_uid, username: Utils.super_admin_username
  end

  # Parses a JSON file containing test data
  # @param file [String]
  # @return [Hash]
  def parse_test_data(file)
    JSON.parse File.read(file)
  end

  def set_test_course_data(file)
    @test_course_data = parse_test_data(file)['courses']
  end

  def set_test_user_data(file)
    @test_user_data = parse_test_data(file)['users']
  end

  def test_specific_user_data(test)
    @test_user_data.select { |u| u['tests'][test] }
  end

  def set_user_of_role(test, role)
    user_data = test_specific_user_data(test).find { |d| d['role'] == role }
    User.new user_data if user_data
  end

  def set_designer(test)
    @designer = set_user_of_role(test, 'Designer')
  end

  def set_lead_ta(test)
    @lead_ta = set_user_of_role(test, 'Lead TA')
  end

  def set_observer(test)
    @observer = set_user_of_role(test, 'Observer')
  end

  def set_reader(test)
    @reader = set_user_of_role(test, 'Reader')
  end

  def set_staff(test)
    @staff = set_user_of_role(test, 'Staff')
  end

  def set_students(test)
    @students = test_specific_user_data(test).select { |d| d['role'] == 'Student' }.map { |d| User.new d }
  end

  def set_ta(test)
    @ta = set_user_of_role(test, 'TA')
  end

  def set_teachers(test)
    @students = test_specific_user_data(test).select { |d| d['role'] == 'Student' }.map { |d| User.new d }
  end

  def set_wait_list_student(test)
    @wait_list_student = set_user_of_role(test, 'Waitlist Student')
  end

  def set_test_users(test)
    roster = []
    roster << set_designer(test)
    roster << set_lead_ta(test)
    roster << set_observer(test)
    roster << set_reader(test)
    roster << set_staff(test)
    roster << set_students(test)
    roster << set_ta(test)
    roster << set_teachers(test)
    roster << set_wait_list_student(test)
    roster.flatten.compact
  end

end
