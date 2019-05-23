class Topic

  attr_accessor :name

  def initialize(name)
    @name = name
  end

  TOPICS = [
      ACADEMIC_PROGRESS = new('Academic Progress'),
      ACADEMIC_PROGRESS_RPT = new('Academic Progress Report (APR)'),
      CHANGE_OF_COLLEGE = new('Change of College'),
      CONCURRENT_ENROLLMENT = new('Concurrent Enrollment'),
      CONTINUED_AFTER_DISMISSAL = new('Continued After Dismissal'),
      COURSE_ADD = new('Course Add'),
      COURSE_DROP = new('Course Drop'),
      COURSE_GRADE_OPTION = new('Course Grade Option'),
      COURSE_UNIT_CHANGE = new('Course Unit Change'),
      DEAN_APPT = new('Dean Appointment'),
      DEGREE_CHECK = new('Degree Check'),
      DEGREE_CHECK_PREP = new('Degree Check Preparation'),
      DEGRESS_REQTS = new('Degree Requirements'),
      DISMISSAL = new('Dismissal'),
      DOUBLE_MAJOR = new('Double Major'),
      EAP = new('Education Abroad Program (EAP)'),
      EAP_RECIPROCITY = new('Education Abroad Program (EAP) Reciprocity'),
      EXCESS_UNITS = new('Excess Units'),
      INCOMPLETES = new('Incompletes'),
      LATE_ENROLLMENT = new('Late Enrollment'),
      MAJORS = new('Majors'),
      MIN_UNIT_PROGRAM = new('Minimum Unit Program'),
      PASS_NO_PASS = new('Pass / Not Pass (PNP)'),
      PRE_MED_ADVISING = new('Pre-Med Advising'),
      PROBATION = new('Probation'),
      PROGRAM_PLANNING = new('Program Planning'),
      READING_AND_COMP = new('Reading & Composition'),
      READMISSION = new('Readmission'),
      REFER_TO_ACAD_DEPT = new('Refer to Academic Department'),
      REFER_TO_CAREER_CENTER = new('Refer to Career Center'),
      REFER_TO_RESOURCES = new('Refer to Resources'),
      REFER_TO_TANG_CENTER = new('Refer to The Tang Center'),
      RETROACTIVE_ADDITION = new('Retroactive Addition'),
      RETROACTIVE_DROP = new('Retroactive Drop'),
      RETROACTIVE_GRADING_OPTION = new('Retroactive Grading Option'),
      RETROACTIVE_UNIT_CHANGE = new('Retroactive Unit Change'),
      RETROACTIVE_WITHDRAWAL = new('Retroactive Withdrawal'),
      SAT_ACAD_PROGRESS_APPEAL = new('Satisfactory Academic Progress (SAP) Appeal'),
      SEMESTER_OUT_RULE = new('Semester Out Rule'),
      SENIOR_RESIDENCY = new('Senior Residency'),
      SIMULTANEOUS_DEGREE = new('Simultaneous Degree'),
      SPECIAL_STUDIES = new('Special Studies'),
      STUDENT_CONDUCT = new('Student Conduct'),
      STUDY_ABROAD = new('Study Abroad'),
      TRANSFER_COURSEWORK = new('Transfer Coursework'),
      WAIVE_COLLECT_REQT = new('Waive College Requirement'),
      WITHDRAWAL = new('Withdrawal')
  ]

end
