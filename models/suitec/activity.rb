class Activity

  attr_accessor :type, :title, :points, :impact_points

  def initialize(type, title, points, impact_points)
    @type = type
    @title = title
    @points = points
    @impact_points = impact_points
  end

  ACTIVITIES = [
    ADD_ASSET_TO_LIBRARY = new('add_asset', 'Add a new asset to the Asset Library', 5, 0),
    VIEW_ASSET = new('view_asset', 'View an asset in the Asset Library', 0, 2),
    GET_VIEW_ASSET = new('get_view_asset', 'Receive a view in the Asset Library', 0, 0),
    LIKE = new('like', 'Like an asset in the Asset Library', 1, 3),
    DISLIKE = new('dislike', 'Dislike an asset in the Asset Library', -1, 0),
    GET_LIKE = new('get_like', 'Receive a like in the Asset Library', 1, 0),
    GET_DISLIKE = new('get_dislike', 'Receive a dislike in the Asset Library', -1, 0),
    COMMENT = new('comment', 'Comment on an asset in the Asset Library', 3, 6),
    GET_COMMENT = new('get_comment', 'Receive a comment in the Asset Library', 1, 0),
    GET_COMMENT_REPLY = new('get_comment_reply', 'Receive a reply on a comment in the Asset Library', 1, 0),
    SUBMIT_ASSIGNMENT = new('submit_assignment', 'Submit a new assignment in Assignments', 20, 0),
    ADD_DISCUSSION_TOPIC = new('discussion_topic', 'Add a new topic in Discussions', 5, 0),
    ADD_DISCUSSION_ENTRY = new('discussion_entry', 'Add an entry on a topic in Discussions', 3, 0),
    GET_DISCUSSION_REPLY = new('get_discussion_entry_reply', 'Receive a reply on an entry in Discussions', 1, 0),
    EXPORT_WHITEBOARD = new('export_whiteboard', 'Export a whiteboard to the Asset Library', 10, 0),
    REMIX_WHITEBOARD = new('remix_whiteboard', 'Remix a whiteboard', 0, 10),
    GET_REMIX_WHITEBOARD = new('get_remix_whiteboard', 'Have one\'s whiteboard remixed', 0, 0),
    ADD_ASSET_TO_WHITEBOARD = new('whiteboard_add_asset', 'Add an asset to a whiteboard', 0, 8),
    GET_ADD_ASSET_TO_WHITEBOARD = new('get_whiteboard_add_asset', 'Have one\'s asset added to a whiteboard', 0, 0),
    LEAVE_CHAT_MESSAGE = new('whiteboard_chat', 'Leave a chat message on a whiteboard', 0, 0)
  ]

  class << self
    private :new
  end

end
