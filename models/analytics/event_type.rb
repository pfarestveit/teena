class EventType

  attr_accessor :desc

  def initialize(desc)
    @desc = desc
  end

  CALIPER_EVENT_TYPES = [
      ADD = new('Added'),
      CREATE = new('Created'),
      DELETE = new('Deleted'),
      HIDE = new('Hid'),
      LIKE = new('Liked'),
      LOGGED_IN = new('LoggedIn'),
      LOGGED_OUT = new('LoggedOut'),
      MODIFY = new('Modified'),
      NAVIGATE = new('NavigatedTo'),
      POST = new('Posted'),
      REMOVE = new('Removed'),
      RETRIEVE = new('Retrieved'),
      SEARCH = new('Searched'),
      SHARE = new('Shared'),
      SHOW = new('Showed'),
      SUBMITTED = new('Submitted'),
      VIEW = new('Viewed')
  ]

  SUITEC_EVENT_TYPES = [
      LAUNCH_ASSET_LIBRARY = new('Launch Asset Library'),
      CREATE_FILE_ASSET = new('Create file asset'),
      CREATE_LINK_ASSET = new('Create link asset'),
      EDIT_ASSET = new('Edit asset'),
      DOWNLOAD_ASSET = new('Download asset'),
      DEEP_LINK_ASSET = new('Deep link asset'),
      VIEW_ASSET = new('View asset'),
      LIKE_ASSET = new('Like asset'),
      UNLIKE_ASSET = new('Unlike asset'),
      CREATE_COMMENT = new('Create asset comment'),
      EDIT_COMMENT = new('Edit asset comment'),
      DELETE_COMMENT = new('Delete asset comment'),
      PIN_ASSET_LIST = new('Asset pinned in list view of Asset Library'),
      PIN_ASSET_DETAIL = new('Asset pinned on asset detail page'),
      PIN_ASSET_PROFILE = new('Asset pinned on user profile page'),
      LIST_ASSETS = new('List assets'),
      SEARCH_ASSETS = new('Search assets'),
      SEARCH_ASSETS_DEEP_LINK = new('Deep link Asset Library search'),
      LAUNCH_WHITEBOARDS = new('Launch Whiteboards'),
      CREATE_WHITEBOARD = new('Create whiteboard'),
      DEEP_LINK_WHITEBOARD = new('Deep link whiteboard'),
      WHITEBOARD_SETTINGS = new('Edit whiteboard settings'),
      EXPORT_WHITEBOARD_ASSET = new('Export whiteboard as asset'),
      EXPORT_WHITEBOARD_IMAGE = new('Export whiteboard as image'),
      LIST_WHITEBOARDS = new('List whiteboards'),
      SEARCH_WHITEBOARDS = new('Search whiteboards'),
      OPEN_WHITEBOARD = new('Open whiteboard'),
      ADD_WHITEBOARD_ELEMENT = new('Add whiteboard element'),
      UPDATE_WHITEBOARD_ELEMENT = new('Update whiteboard element'),
      DELETE_WHITEBOARD_ELEMENT = new('Delete whiteboard element'),
      SELECT_WHITEBOARD_ELEMENT = new('Select whiteboard elements'),
      UPDATE_WHITEBOARD_LAYERS = new('Change whiteboard layer order'),
      OPEN_ASSET_FROM_WHITEBOARD = new('Open asset from whiteboard'),
      WHITEBOARD_COPY = new('Whiteboard copy'),
      WHITEBOARD_PASTE = new('Whiteboard paste'),
      WHITEBOARD_ZOOM = new('Zoom whiteboard'),
      CREATE_CHAT_MSG = new('Create whiteboard chat message'),
      GET_CHAT_MSG = new('Get whiteboard chat messages'),
      LAUNCH_ENGAGEMENT_INDEX = new('Launch Engagement Index'),
      GET_ENGAGEMENT_INDEX = new('Get engagement index'),
      GET_POINTS_CONFIG = new('Get points configuration'),
      LINK_TO_ENGAGEMENT_INDEX = new('Link to Engagement Index'),
      SEARCH_ENGAGEMENT_INDEX = new('Search engagement index'),
      SORT_ENGAGEMENT_INDEX = new('Sort engagement index'),
      EDIT_SCORE_SHARING = new('Update engagement index share'),
      LAUNCH_IMPACT_STUDIO = new('Launch Impact Studio'),
      VIEW_PROFILE = new('View user profile'),
      SEARCH_PROFILE = new('Search for user profile'),
      BROWSE_PROFILE = new('Browse another user profile using pagination feature'),
      ZOOM_TIMELINE = new('Zoom activity timeline'),
      FILTER_EVERYONE_ASSETS = new('Change profile page community assets filter'),
      FILTER_TOTAL_ACTIVITIES = new('Change profile page total activities filter'),
      FILTER_USER_ASSETS = new('Change profile page user assets filter'),
      BOOKMARKLET = new('Install bookmarklet instructions')
  ]

  class << self
    private :new
  end

end
