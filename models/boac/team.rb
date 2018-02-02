class Team < Cohort

  attr_accessor :code

  def initialize(team_data)
    team_data.each { |k, v| public_send("#{k}=", v) }
  end

  TEAMS = [
      BAM = new({code: 'BAM', name: 'Men\'s Baseball'}),
      BBM = new({code: 'BBM', name: 'Men\'s Basketball'}),
      BBW = new({code: 'BBW', name: 'Women\'s Basketball'}),
      CCM = new({code: 'CCM', name: 'Men\'s Cross Country'}),
      CCW = new({code: 'CCW', name: 'Women\'s Cross Country'}),
      CRM = new({code: 'CRM', name: 'Men\'s Crew'}),
      CRW = new({code: 'CRW', name: 'Women\'s Crew'}),
      EMX = new({code: 'EMX', name: 'Equipment Managers'}),
      FBM = new({code: 'FBM', name: 'Football'}),
      FHW = new({code: 'FHW', name: 'Women\'s Field Hockey'}),
      GOM = new({code: 'GOM', name: 'Men\'s Golf'}),
      GOW = new({code: 'GOW', name: 'Women\'s Golf'}),
      GYM = new({code: 'GYM', name: 'Men\'s Gymnastics'}),
      GYW = new({code: 'GYW', name: 'Women\'s Gymnastics'}),
      LCW = new({code: 'LCW', name: 'Women\'s Lacrosse'}),
      RGM = new({code: 'RGM', name: 'Men\'s Rugby'}),
      SBW = new({code: 'SBW', name: 'Women\'s Softball'}),
      SCM = new({code: 'SCM', name: 'Men\'s Soccer'}),
      SCW = new({code: 'SCW', name: 'Women\'s Soccer'}),
      SDM = new({code: 'SDM', name: 'Men\'s SwimDive'}),
      SDW = new({code: 'SDW', name: 'Women\'s SwimDive'}),
      STX = new({code: 'STX', name: 'Student Trainers'}),
      SVW = new({code: 'SVW', name: 'Women\'s Beach Volleyball'}),
      TIM = new({code: 'TIM', name: 'Men\'s Indoor Track & Field'}),
      TIW = new({code: 'TIW', name: 'Women\s Indoor Track & Field'}),
      TNM = new({code: 'TNM', name: 'Men\'s Tennis'}),
      TNW = new({code: 'TNW', name: 'Women\'s Tennis'}),
      TOM = new({code: 'TOM', name: 'Men\'s TrackCC'}),
      TOW = new({code: 'TOW', name: 'Women\'s TrackCC'}),
      VBW = new({code: 'VBW', name: 'Women\'s Volleyball'}),
      WPM = new({code: 'WPM', name: 'Men\'s Water Polo'}),
      WPW = new({code: 'WPW', name: 'Women\'s Water Polo'})
  ]

end
