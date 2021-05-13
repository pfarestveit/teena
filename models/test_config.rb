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

  def set_user_of_role(test, role, user_klass = nil)
    user_data = test_specific_user_data(test).find { |d| d['role'] == role }
    if user_data
      user_klass ? user_klass.new(user_data) : User.new(user_data)
    end
    User.new user_data if user_data
  end

  def set_designer(test, user_klass = nil)
    @designer = set_user_of_role(test, 'Designer', user_klass)
  end

  def set_lead_ta(test, user_klass = nil)
    @lead_ta = set_user_of_role(test, 'Lead TA', user_klass)
  end

  def set_observer(test, user_klass = nil)
    @observer = set_user_of_role(test, 'Observer', user_klass)
  end

  def set_reader(test, user_klass = nil)
    @reader = set_user_of_role(test, 'Reader', user_klass)
  end

  def set_staff(test, user_klass = nil)
    @staff = set_user_of_role(test, 'Staff', user_klass)
  end

  def set_students(test, user_klass = nil)
    @students = test_specific_user_data(test).select { |d| d['role'] == 'Student' }.map do |d|
      user_klass ? user_klass.new(d) : User.new(d)
    end
  end

  def set_ta(test, user_klass = nil)
    @ta = set_user_of_role(test, 'TA', user_klass)
  end

  def set_teachers(test, user_klass = nil)
    @teachers = test_specific_user_data(test).select { |d| d['role'] == 'Teacher' }.map do |d|
      user_klass ? user_klass.new(d) : User.new(d)
    end
  end

  def set_wait_list_student(test, user_klass = nil)
    @wait_list_student = set_user_of_role(test, 'Waitlist Student', user_klass)
  end

  def set_test_users(test, user_klass = nil)
    roster = []
    roster << set_designer(test, user_klass)
    roster << set_lead_ta(test, user_klass)
    roster << set_observer(test, user_klass)
    roster << set_reader(test, user_klass)
    roster << set_staff(test, user_klass)
    roster << set_students(test, user_klass)
    roster << set_ta(test, user_klass)
    roster << set_teachers(test, user_klass)
    roster << set_wait_list_student(test, user_klass)
    roster.flatten.compact
  end

end
