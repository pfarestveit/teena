class Squad

  attr_accessor :code, :name, :team

  def initialize(code, name, team)
    @code = code
    @name = name
    @team = team
  end

  SQUADS = [
      MBB_AA = new('MBB-AA', 'Men\'s Baseball', Team::BAM),
      MBK_AA = new('MBK-AA', 'Men\'s Basketball', Team::BBM),
      MCR_AA = new('MCR-AA', 'Men\'s Crew', Team::CRM),
      MFB_DB = new('MFB-DB', 'Football, Defensive Backs', Team::FBM),
      MFB_DL = new('MFB-DL', 'Football, Defensive Line', Team::FBM),
      MFB_MLB = new('MFB-MLB', 'Football, Inside Linebackers', Team::FBM),
      MFB_OL = new('MFB-OL', 'Football, Offensive Line', Team::FBM),
      MFB_OLB = new('MFB-OLB', 'Football, Outside Linebackers', Team::FBM),
      MFB_QB = new('MFB-QB', 'Football, Quarterbacks', Team::FBM),
      MFB_RB = new('MFB-RB', 'Football, Running Backs', Team::FBM),
      MFB_ST = new('MFB-ST', 'Football, Special Teams', Team::FBM),
      MFB_TE = new('MFB-TE', 'Football, Tight Ends', Team::FBM),
      MFB_WR = new('MFB-WR', 'Football, Wide Receivers', Team::FBM),
      MGO_AA = new('MGO-AA', 'Men\'s Golf', Team::GOM),
      MGY_AA = new('MGY-AA', 'Men\'s Gymnastics', Team::GYM),
      MRU_AA = new('MRU-AA', 'Men\'s Rugby', Team::RGM),
      MSC_AA = new('MSC-AA', 'Men\'s Soccer', Team::SCM),
      MSW_AA = new('MSW-AA', 'Men\'s SwimDive', Team::SDM),
      MSW_DV = new('MSW-DV', 'Men\'s SwimDive, Divers', Team::SDM),
      MSW_SW = new('MSW-SW', 'Men\'s SwimDive, Swimmers', Team::SDM),
      MTE_AA = new('MTE-AA', 'Men\'s Tennis', Team::TNM),
      MTR_AA = new('MTR-AA', 'Men\'s TrackCC', Team::TOM),
      MTR_DC = new('MTR-DC', 'Men\'s TrackCC, Distance CC', Team::TOM),
      MTR_JP = new('MTR-JP', 'Men\'s TrackCC, Jumps', Team::TOM),
      MTR_MD = new('MTR-MD', 'Men\'s TrackCC, Middle Dist', Team::TOM),
      MTR_MT = new('MTR-MT', 'Men\'s TrackCC, Multis', Team::TOM),
      MTR_PV = new('MTR-PV', 'Men\'s TrackCC, Pole Vault', Team::TOM),
      MTR_SH = new('MTR-SH', 'Men\'s TrackCC, Sprints Hurdles', Team::TOM),
      MTR_TH = new('MTR-TH', 'Men\'s TrackCC, Throws', Team::TOM),
      MWP_AA = new('MWP-AA', 'Men\'s Water Polo', Team::WPM),
      WBK_AA = new('WBK-AA', 'Women\'s Basketball', Team::BBW),
      WBV_AA = new('WBV-AA', 'Women\'s Beach Volleyball', Team::SVW),
      WCR_AA = new('WCR-AA', 'Women\'s Crew', Team::CRW),
      WFH_AA = new('WFH-AA', 'Women\'s Field Hockey', Team::FHW),
      WGO_AA = new('WGO-AA', 'Women\'s Golf', Team::GOW),
      WGY_AA = new('WGY-AA', 'Women\'s Gymnastics', Team::GYW),
      WLC_AA = new('WLC-AA', 'Women\'s Lacrosse', Team::LCW),
      WSC_AA = new('WSC-AA', 'Women\'s Soccer', Team::SCW),
      WSF_AA = new('WSF-AA', 'Women\'s Softball', Team::SBW),
      WSW_DV = new('WSW-DV', 'Women\'s SwimDive, Divers', Team::SDW),
      WSW_SW = new('WSW-SW', 'Women\'s SwimDive, Swimmers', Team::SDW),
      WTE_AA = new('WTE-AA', 'Women\'s Tennis', Team::TNW),
      WTR_DC = new('WTR-DC', 'Women\'s TrackCC, Distance CC', Team::TOW),
      WTR_JP = new('WTR-JP', 'Women\'s TrackCC, Jumps', Team::TOW),
      WTR_MD = new('WTR-MD', 'Women\'s TrackCC, Middle Dist', Team::TOW),
      WTR_MT = new('WTR-MT', 'Women\'s TrackCC, Multis', Team::TOW),
      WTR_PV = new('WTR-PV', 'Women\'s TrackCC, Pole Vault', Team::TOW),
      WTR_SH = new('WTR-SH', 'Women\'s TrackCC, Sprints Hurdles', Team::TOW),
      WTR_TH = new('WTR-TH', 'Women\'s TrackCC, Throws', Team::TOW),
      WVB_AA = new('WVB-AA', 'Women\'s Volleyball', Team::VBW),
      WWP_AA = new('WWP-AA', 'Women\'s Water Polo', Team::WPW)
  ]

  class << self
    private :new
  end

end
