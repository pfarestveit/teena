class OECDepartments

  attr_accessor :dept_code, :dept_name, :file_name, :form_code, :eval_types, :ets_managed, :catalog_ids

  def initialize(dept_code, file_name, form_code, eval_types, ets_managed, catalog_ids = nil)
    @dept_code = dept_code
    @dept_name = file_name
    @form_code = form_code
    @eval_types = eval_types
    @ets_managed = ets_managed
    @catalog_ids = catalog_ids
  end

  DEPARTMENTS = [
      AEROSPC = new('AEROSPC', 'Military Affairs', 'MIL AFF', %w(F G), true),
      AFRICAM = new('AFRICAM', 'African American Studies', 'AFRICAM', %w(F G), true),
      AFRIKANS = new('AFRKANS', 'German', 'GERMAN', %w(F), true),
      AGR_CHM = new('AGR CHM', 'Plant and Microbial Biology', 'PLANTBI', nil, true),
      AMERSTD = new('AMERSTD', 'American Studies', 'AMERSTD', %w(F G), true),
      ANTHRO = new('ANTHRO', 'Anthropology', 'ANTHRO', %w(F G), true),
      A_RESEC = new('A,RESEC', 'Agricultural and Resource Economics', 'A_RESEC', %w(F G), true),
      ARABIC = new('ARABIC', 'Near Eastern Studies', 'ARABIC', %w(F G), true),
      ARCH = new('ARCH', 'Architecture', 'ARCH', %w(F G), true),
      ARMENI = new('ARMENI', 'Slavic Languages and Literatures', 'ARMENI', %w(F G), true),
      ART = new('ART', 'Art Practice', 'ART', %w(F G), true),
      ASIANST = new('ASIANST', 'International and Area Studies', 'IAS', %w(F G), true),
      AST = new('AST', 'Engineering', 'ENGIN', nil, false),
      ASTRON = new('ASTRON', 'Astronomy', 'ASTRON', %w(F G), true),
      BANGLA = new('BANGLA', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      BIC = new('BIC', 'Undergraduate and Interdisciplinary Studies', 'BIC', %w(F G), true),
      BIO_ENG = new('BIO ENG', 'Bioengineering', 'BIO ENG', nil, false),
      BOSCRSR = new('BOSCRSR', 'Slavic Languages and Literatures', 'BOSCRSR', %w(F G), true),
      BUDDSTD = new('BUDDSTD', 'South and Southeast Asian Studies', 'BUDDSTD', %w(F G), true),
      BURMESE = new('BURMESE', 'South and Southeast Asian Studies', 'BURMESE', %w(F G), true),
      CAL_TEACH = new('CALTEACH', 'CalTeach', 'CALTEACH', %w(F G), true),
      CATALAN = new('CATALAN', 'Spanish and Portuguese', 'SPANISH', %w(LANG LECT SEMI WRIT), true),
      CELTIC = new('CELTIC', 'Celtic Studies', 'CELTIC', %w(F G), true),
      CHEM = new('CHEM', 'Chemistry', 'CHEM', %w(F G), true),
      CHINESE = new('CHINESE', 'East Asian Languages and Cultures', 'CHINESE', %w(F G), true),
      CHM_ENG = new('CHM ENG','Chemical and Biomolecular Engineering', 'CHM ENG', %w(F G), true),
      CIV_ENG = new('CIV ENG', 'Civil and Environmental Engineering', 'CIV ENG', nil, false),
      CLASSIC = new('CLASSIC', 'Classics', 'CLASSIC', %w(F G), true),
      CMP_BIO = new('CMP BIO', 'Bioengineering', 'CMP BIO', nil, true),
      COG_SCI = new('COG SCI', 'International and Area Studies', 'IAS', %w(F G), true),
      COLWRIT = new('COLWRIT', 'College Writing', 'COLWRIT', %w(F G), true),
      COM_LIT = new('COM LIT', 'Comparative Literature', 'COM LIT', %w(G), true),
      COMPBIO = new('COMPBIO', 'Graduate Division', 'COMPBIO', nil, false),
      COMPSCI = new('COMPSCI', 'Electrical Engineering and Computer Sciences', 'COMPSCI', nil, false),
      CUNEIF = new('CUNEIF', 'Near Eastern Studies', 'CUNEIF', %w(F G), true),
      CY_PLAN = new('CY PLAN', 'City and Regional Planning', 'CY PLAN', %w(F G), true),
      CZECH = new('CZECH', 'Slavic Languages and Literatures', 'CZECH', %w(F G), true),
      CYBER = new('CYBER', 'Information', 'CYBER', %w(F G), true),
      DANISH = new('DANISH', 'Scandinavian', 'DANISH', %w(F G), true),
      DATASCI = new('DATASCI', 'Information', 'DATASCI', nil, true),
      DES_INV = new('DES INV', 'Engineering', 'ENGIN', nil, false),
      DEV_ENG = new('DEV ENG', 'Civil and Environmental Engineering', 'CIV ENG', nil, false),
      DEV_STD = new('DEV STD', 'International and Area Studies', 'IAS', %w(F G), true),
      DEVP = new('DEVP', 'Graduate Division', 'DEVP', nil, true),
      DUTCH = new('DUTCH', 'German', 'GERMAN', %w(F), true),
      EA_LANG = new('EA LANG', 'East Asian Languages and Cultures', 'EA LANG', %w(F G), true),
      ECON = new('ECON', 'Economics', 'ECON', %w(F G), true),
      EDUC = new('EDUC', 'Education', 'EDUC', %w(F G), true),
      EECS = new('EECS', 'Electrical Engineering and Computer Sciences', 'EL ENG', nil, false),
      EGYPT = new('EGYPT', 'Near Eastern Studies', 'EGYPT', %w(F G), true),
      EL_ENG = new('EL ENG', 'Electrical Engineering and Computer Sciences', 'EL ENG', nil, false),
      ENE_RES = new('ENE,RES', 'Energy and Resources Group', 'ENE_RES', %w(F G), true),
      ENGIN = new('ENGIN', 'Engineering', 'ENGIN', nil, false),
      ENGLISH = new('ENGLISH', 'English', 'ENGLISH', %w(F G), true),
      ENVECON = new('ENVECON', 'Agricultural and Resource Economics', 'ENVECON', %w(F G), true),
      ENV_DES = new('ENV DES', 'Architecture', 'ENV DES', %w(F G), true),
      ENV_SCI = new('ENV SCI',  'Environmental Science, Policy and Management', 'ESPM', %w(F G), true),
      EPS = new('EPS', 'Earth and Planetary Science', 'EPS', %w(F G), true),
      ESPM = new('ESPM', 'Environmental Science, Policy and Management', 'ESPM', %w(F G), true),
      ETH_STD = new('ETH STD', 'Ethnic Studies', 'ETH STD', %w(F G), true),
      EUST = new('EUST', 'International and Area Studies', 'EUST', %w(F G), true),
      FILIPN = new('FILIPN', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      FILM = new('FILM', 'Film and Media', 'FILM', %w(F G), true),
      FINNISH = new('FINNISH', 'Scandinavian', 'FINNISH', %w(F G), true),
      FRENCH = new('FRENCH', 'French', 'FRENCH', %w(F G), true),
      FSSEM = new('FSSEM', 'Freshman and Sophomore Seminars', 'FSSEM', nil, true),
      GEOG = new('GEOG', 'Geography', 'GEOG', %w(F G), true),
      GERMAN = new('GERMAN', 'German', 'GERMAN', %w(F), true),
      GLOBAL = new('GLOBAL', 'International and Area Studies', 'IAS', %w(F G), true),
      GMS = new('GMS', 'Global Metropolitan Studies', 'GMS', %w(F G), true),
      GPP = new('GPP', 'International and Area Studies', 'IAS', %w(F G), true),
      GSPDP = new('GSPDP', 'Graduate Division', 'LAN PRO', nil, true),
      GWS = new('GWS', 'Gender and Women\'s Studies', 'GWS', %w(F G), true),
      HEBREW = new('HEBREW', 'Near Eastern Studies', 'HEBREW', %w(F G), true),
      HIN_URD = new('HIN-URD', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      HINDI = new('HINDI', 'South and Southeast Asian Studies', 'HINDI', %w(F G), true),
      HISTART = new('HISTART', 'History of Art', 'HISTART', %w(F G), true),
      HISTORY = new('HISTORY', 'History', 'HISTORY', %w(F G), true),
      HMEDSCI = new('HMEDSCI', 'Public Health', 'PB HLTH', nil, false),
      HUM = new('HUM', 'L&S Arts and Humanities', 'HUM', %w(F G), true),
      HUNGARI = new('HUNGARI', 'Slavic Languages and Literatures', 'HUNGARI', %w(F G), true),
      IAS = new('IAS', 'International and Area Studies', 'IAS', %w(F G), true),
      ICELAND = new('ICELAND', 'Scandinavian', 'ICELAND', %w(F G), true),
      ILA = new('ILA', 'Spanish and Portuguese', 'SPANISH', %w(LANG LECT SEMI WRIT), true),
      IND_ENG = new('IND ENG', 'Industrial Engineering and Operations Research', 'IND ENG', nil, false),
      INDONES = new('INDONES', 'South and Southeast Asian Studies', 'INDONES', %w(F G), true),
      INFO = new('INFO', 'Information', 'INFO', %w(F G), true),
      INTEGBI = new('INTEGBI', 'Integrative Biology', 'INTEGBI', %w(F G), true),
      IRANIAN = new('IRANIAN', 'Near Eastern Studies', 'IRANIAN', %w(F G), true),
      ISF = new('ISF', 'Interdisciplinary Studies Field', 'ISF', nil, true),
      ITALIAN = new('ITALIAN', 'Italian Studies', 'ITALIAN', %w(F G), true),
      JAPAN = new('JAPAN', 'East Asian Languages and Cultures', 'JAPAN', %w(F G), true),
      JOURN = new('JOURN', 'Journalism', 'JOURN', nil, true),
      KHMER = new('KHMER', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      KOREAN = new('KOREAN', 'East Asian Languages and Cultures', 'KOREAN', %w(F G), true),
      L_AND_S = new('L & S', 'Undergraduate and Interdisciplinary Studies', 'L & S', %w(F G), true, %w(W1 1W)),
      LAN_PRO = new('LAN PRO', 'Graduate Division', 'LAN PRO', nil, true),
      LATAMST = new('LATAMST', 'Graduate Division', 'LAN PRO', nil, true),
      LD_ARCH = new('LD ARCH', 'Real Estate Development and Design', 'RDEV', %w(F G), true),
      LEGALST = new('LEGALST', 'Legal Studies', 'LEGALST', %w(F G), true),
      LGBT = new('LGBT', 'Gender and Women\'s Studies', 'GWS', %w(F G), true),
      LINGUIS = new('LINGUIS', 'Linguistics', 'LINGUIS', %w(F G), true),
      MALAY_I = new('MALAY/I', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      MATH = new('MATH', 'Mathematics', 'MATH', %w(F G), true),
      MAT_SCI = new('MAT SCI', 'Materials Science and Engineering', 'MAT SCI', nil, false),
      MCELLBI = new('MCELLBI', 'Molecular and Cell Biology', 'MCELLBI', %w(F G), true),
      MEC_ENG = new('MEC ENG', 'Mechanical Engineering', 'MEC ENG', nil, false),
      MEDIAST = new('MEDIAST', 'Media Studies', 'MEDIAST', %w(F G), true),
      M_E_STU = new('M E STU', 'International and Area Studies', 'IAS', %w(F G), true),
      MONGOLN = new('MONGOLN', 'East Asian Languages and Cultures', 'MONGOLN', %w(F G), true),
      MIL_AFF = new('MIL AFF', 'Military Affairs', 'MIL AFF', %w(F G), true),
      MIL_SCI = new('MIL SCI', 'Military Affairs', 'MIL SCI', %w(F G), true),
      MUSIC = new('MUSIC', 'Music', 'MUSIC', %w(F G), true),
      NAT_RES = new('NAT RES', 'Natural Resources', 'NAT RES', nil, false),
      NAV_SCI = new('NAV SCI', 'Military Affairs', 'NAV SCI', %w(F G), true),
      NE_STUD = new('NE STUD', 'Near Eastern Studies', 'NE STUD', %w(F G), true),
      NEUROSC = new('NEUROSC', 'Helen Wills Neuroscience', 'NEUROSC', nil, true),
      NORWEGN = new('NORWEGN', 'Scandinavian', 'NORWEGN', %w(F G), true),
      NSE = new('NSE', 'Engineering', 'ENGIN', nil, false),
      NUC_ENG = new('NUC ENG', 'Nuclear Engineering', 'NUC ENG', nil, false),
      NUSCTX = new('NUSCTX', 'Nutritional Sciences and Toxicology', 'NUSCTX', nil, true),
      NWMEDIA = new('NWMEDIA', 'New Media', 'NWMEDIA', nil, true),
      PACS = new('PACS', 'International and Area Studies', 'IAS', %w(F G), true),
      PB_HLTH = new('PB HLTH', 'Public Health', 'PB HLTH', nil, false),
      PERSIAN = new('PERSIAN', 'Near Eastern Studies', 'PERSIAN', %w(F G), true),
      PHILOS = new('PHILOS', 'Philosophy', 'PHILOS', %w(F G), true),
      PHYS_ED = new('PHYS ED', 'Physical Education', 'PHYS ED', %w(F G), true),
      PHYSICS = new('PHYSICS', 'Physics', 'PHYSICS', %w(F G), true),
      PLANTBI = new('PLANTBI', 'Plant and Microbial Biology', 'PLANTBI', nil, true),
      POLECON = new('POLECON', 'International and Area Studies', 'IAS', %w(F G), true),
      POLISH = new('POLISH', 'Slavic Languages and Literatures', 'POLISH', %w(F G), true),
      POL_SCI = new('POL SCI', 'Political Science', 'POL SCI', %w(F G), true),
      PORTUG = new('PORTUG', 'Spanish and Portuguese', 'SPANISH', %w(LANG LECT SEMI WRIT), true),
      PSYCH = new('PSYCH', 'Psychology', 'PSYCH', nil, true),
      PUB_POL = new('PUB POL', 'Goldman School of Public Policy', 'PUB POL', nil, false),
      PUNJABI = new('PUNJABI', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      RDEV = new('RDEV', 'Real Estate Development and Design', 'RDEV', %w(F G), true),
      RELIGST = new('RELIGST', 'Undergraduate and Interdisciplinary Studies', 'UGIS', %w(F G), true),
      RHETOR = new('RHETOR', 'Rhetoric', 'RHETOR', %w(F G), true),
      RUSSIAN = new('RUSSIAN', 'Slavic Languages and Literatures', 'RUSSIAN', %w(F G), true),
      SANSKR = new('SANSKR', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      S_ASIAN = new('S ASIAN', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      SCANDIN = new('SCANDIN', 'Scandinavian', 'SCANDIN', %w(F G), true),
      SEASIAN = new('SEASIAN', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      SEMITIC = new('SEMITIC', 'Near Eastern Studies', 'SEMITIC', %w(F G), true),
      S_SEASN = new('S,SEASN', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      SLAVIC = new('SLAVIC', 'Slavic Languages and Literatures', 'SLAVIC', %w(F G), true),
      SOC_WEL = new('SOC WEL', 'Social Welfare', 'SOC WEL', nil, true, %w(290)),
      SOCIOL = new('SOCIOL', 'Sociology', 'SOCIOL', %w(F G), true),
      SPANISH = new('SPANISH', 'Spanish and Portuguese', 'SPANISH', %w(LANG LECT SEMI WRIT), true),
      STAT = new('STAT', 'Statistics', 'STAT', %w(F G), true),
      SWEDISH = new('SWEDISH', 'Scandinavian', 'SWEDISH', %w(F G), true),
      TAGALG = new('TAGALG', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      TAMIL = new('TAMIL', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      TELUGU = new('TELUGU', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      THAI = new('THAI', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      THEATER = new('THEATER', 'Theater, Dance and Performance Studies', 'THEATER', %w(F G), true),
      TIBETAN = new('TIBETAN', 'South and Southeast Asian Studies', 'TIBETAN', %w(F G), true),
      TURKISH = new('TURKISH', 'Near Eastern Studies', 'TURKISH', %w(F G), true),
      UGIS = new('UGIS', 'Undergraduate and Interdisciplinary Studies', 'UGIS', %w(F G), true),
      URDU = new('URDU', 'South and Southeast Asian Studies', 'URDU', %w(F G), true),
      VIETNMS = new('VIETNMS', 'South and Southeast Asian Studies', 'S_SEASN', %w(F G), true),
      VIS_STD = new('VIS STD', 'Architecture', 'VIS STD', %w(F G), true),
      YIDDISH = new('YIDDISH', 'German', 'GERMAN', %w(F), true)
  ]

end
