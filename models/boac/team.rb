class Team

  attr_accessor :code, :name

  def initialize(code, name)
    @code = code
    @name = name
  end

  TEAMS = [
      BAM = new('BAM', 'Baseball - Men'),
      BBM = new('BBM', 'Basketball - Men'),
      BBW = new('BBW', 'Basketball - Women'),
      CCM = new('CCM', 'Cross Country - Men'),
      CCW = new('CCW', 'Cross Country - Women'),
      CRM = new('CRM', 'Crew - Men'),
      CRW = new('CRW', 'Crew - Women'),
      EMX = new('EMX', 'Equipment Managers'),
      FBM = new('FBM', 'Football - Men'),
      FHW = new('FHW', 'Field Hockey - Women'),
      GOM = new('GOM', 'Golf - Men'),
      GOW = new('GOW', 'Golf - Women'),
      GYM = new('GYM', 'Gymnastics - Men'),
      GYW = new('GYW', 'Gymnastics - Women'),
      LCW = new('LCW', 'Lacrosse - Women'),
      RGM = new('RGM', 'Rugby - Men'),
      SBW = new('SBW', 'Softball - Women'),
      SCM = new('SCM', 'Soccer - Men'),
      SCW = new('SCW', 'Soccer - Women'),
      SDM = new('SDM', 'Swimming & Diving - Men'),
      SDW = new('SDW', 'Swimming & Diving - Women'),
      STX = new('STX', 'Student Trainers'),
      SVW = new('SVW', 'Sand Volleyball - Women'),
      TIM = new('TIM', 'Indoor Track & Field - Men'),
      TIW = new('TIW', 'Indoor Track & Field - Women'),
      TNM = new('TNM', 'Tennis - Men'),
      TNW = new('TNW', 'Tennis - Women'),
      TOM = new('TOM', 'Outdoor Track & Field - Men'),
      TOW = new('TOW', 'Outdoor Track & Field - Women'),
      VBW = new('VBW', 'Volleyball - Women'),
      WPM = new('WPM', 'Water Polo - Men'),
      WPW = new('WPW', 'Water Polo - Women')
  ]

  class << self
    private :new
  end

end
