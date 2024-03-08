class Topic

  attr_accessor :name,:id

  def initialize(name, id=nil)
    @name = name
    @id = id
  end

  TOPICS = [
      ACADEMIC_DIFFICULTY = new('Academic Difficulty'),
      ACADEMIC_INTERESTS = new('Academic Interests'),
      ACADEMIC_PLAN = new('Academic Plan'),
      ACADEMIC_PROGRESS = new('Academic Progress'),
      ACADEMIC_PROGRESS_RPT = new('Academic Progress Report (APR)'),
      ACADEMIC_SUPPORT = new('Academic Support'),
      ADVISING_HOLDS = new('Advising Holds'),
      AP_IB_GCE_TEST_UNITS = new('AP/IB/GCE test units'),
      BREADTH_REQTS = new('Breadth requirement(s)'),
      CAREER_INTERNSHIP = new('Career/Internship'),
      CHANGE_GRADING_OPTION = new('Change Grading Option'),
      CHANGE_OF_COLLEGE = new('Change of College'),
      CHANGE_OF_MAJOR = new('Change of Major'),
      COCI = new('COCI'),
      CONCURRENT_ENROLLMENT = new('Concurrent Enrollment'),
      CONTINUED_AFTER_DISMISSAL = new('Continued After Dismissal'),
      COURSE_ADD = new('Course Add'),
      COURSE_DROP = new('Course Drop'),
      COURSE_GRADE_OPTION = new('Course Grade Option'),
      COURSE_SELECTION = new('Course Selection'),
      COURSE_UNIT_CHANGE = new('Course Unit Change'),
      CURRENTLY_DISMISSED_PLANNING = new('Currently Dismissed/Planning'),
      DEAN_APPT = new('Dean Appointment'),
      DEGREE_CHECK = new('Degree Check'),
      DEGREE_CHECK_PREP = new('Degree Check Preparation'),
      DEGRESS_REQTS = new('Degree Requirements'),
      DISMISSAL = new('Dismissal'),
      DOUBLE_MAJOR = new('Double Major'),
      EAP = new('Education Abroad Program (EAP)'),
      EAP_RECIPROCITY = new('Education Abroad Program (EAP) Reciprocity'),
      EDUCATIONAL_GOALS = new('Educational Goals'),
      ELIGIBILITY = new('Eligibility'),
      ENROLLING_ANOTHER_SCHOOL = new('Enrolling At Another School'),
      EVAL_COURSES_ELSEWHERE = new('Evaluation of course(s) taken elsewhere'),
      EXCESS_UNITS = new('Excess Units'),
      FINANCIAL_AID_BUDGETING = new('Financial Aid/Budgeting'),
      GRADUATION_CHECK = new('Graduation Check'),
      GRADUATION_PLAN = new('Graduation Plan'),
      GRADUATION_PROGRESS = new('Graduation Progress'),
      INCOMPLETES = new('Incompletes'),
      JOINT_MAJOR = new('Joint Major'),
      LATE_ENROLLMENT = new('Late Enrollment'),
      MAJORS = new('Majors'),
      MIN_UNIT_PROGRAM = new('Minimum Unit Program'),
      MINORS = new('Minors'),
      PASS_NO_PASS = new('Pass / Not Pass (PNP)'),
      PERSONAL = new('Personal'),
      PETITION = new('Petition'),
      POST_GRADUATION = new('Post-Graduation'),
      PRE_MED_PRE_HEALTH = new('Pre-Med/Pre-Health'),
      PREMED_PRE_HEALTH_ADVISING = new('Premed/Pre-Health Advising'),
      PROBATION = new('Probation'),
      PROCTORING = new('Proctoring'),
      PROGRAM_PLANNING = new('Program Planning'),
      READING_AND_COMP = new('Reading & Composition'),
      READMISSION = new('Readmission'),
      READMISSION_AFTER_DISMISSAL = new('Readmission After Dismissal'),
      REFER_TO_ACAD_DEPT = new('Refer to Academic Department'),
      REFER_TO_CAREER_CENTER = new('Refer to Career Center'),
      REFER_TO_RESOURCES = new('Refer to Resources'),
      REFER_TO_TANG_CENTER = new('Refer to The Tang Center'),
      REQUIREMENTS = new('Requirements'),
      RESEARCH = new('Research'),
      RETROACTIVE_ADD = new('Retroactive Add'),
      RETROACTIVE_DROP = new('Retroactive Drop'),
      RETROACTIVE_UNIT_CHANGE = new('Retroactive Unit Change'),
      RETROACTIVE_WITHDRAWAL = new('Retroactive Withdrawal'),
      SAP = new('SAP'),
      SAT_ACAD_PROGRESS_APPEAL = new('Satisfactory Academic Progress (SAP) Appeal'),
      SCHEDULE_PLANNING_LATE_ACTION = new('Schedule Planning, Late Action'),
      SCHEDULING = new('Scheduling'),
      SEMESTER_OUT_RULE = new('Semester Out Rule'),
      SENIOR_RESIDENCY = new('Senior Residency'),
      SIMULTANEOUS_DEGREE = new('Simultaneous Degree'),
      SPECIAL_STUDIES = new('Special Studies'),
      STUDENT_CONDUCT = new('Student Conduct'),
      STUDY_ABROAD = new('Study Abroad'),
      TRANSFER_COURSEWORK = new('Transfer Coursework'),
      TRANSITION_SUPPORT = new('Transition Support'),
      TRAVEL_CONFLICTS = new('Travel Conflicts'),
      WAIVE_COLLECT_REQT = new('Waive College Requirement'),
      WITHDRAWAL = new('Withdrawal'),
      OTHER = new('Other / Reason not listed')
  ]

end
