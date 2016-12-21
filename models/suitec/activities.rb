class Activities

  attr_accessor :type, :title, :points

  def initialize(type, title, points)
    @type = type
    @title = title
    @points = points
  end

  VIEW_ASSET = new('view_asset', 'View an asset in the Asset Library', 0)
  ADD_ASSET_TO_LIBRARY = new('add_asset', 'Add a new asset to the Asset Library', 5)
  LIKE = new('like', 'Like an asset in the Asset Library', 1)
  DISLIKE = new('dislike', 'Dislike an asset in the Asset Library', -1)
  GET_LIKE = new('get_like', 'Receive a like in the Asset Library', 1)
  GET_DISLIKE = new('get_dislike', 'Receive a dislike in the Asset Library', -1)
  COMMENT = new('comment', 'Comment on an asset in the Asset Library', 3)
  GET_COMMENT = new('get_comment', 'Receive a comment in the Asset Library', 1)
  GET_COMMENT_REPLY = new('get_comment_reply', 'Receive a reply on a comment in the Asset Library', 1)
  SUBMIT_ASSIGNMENT = new('submit_assignment', 'Submit a new assignment in Assignments', 20)
  ADD_DISCUSSION_TOPIC = new('discussion_topic', 'Add a new topic in Discussions', 5)
  ADD_DISCUSSION_ENTRY = new('discussion_entry', 'Add an entry on a topic in Discussions', 3)
  GET_DISCUSSION_REPLY = new('get_discussion_entry_reply', 'Receive a reply on an entry in Discussions', 1)
  EXPORT_WHITEBOARD = new('export_whiteboard', 'Export a whiteboard to the Asset Library', 10)
  ADD_ASSET_TO_WHITEBOARD = new('whiteboard_add_asset', 'Add an asset to a whiteboard', 0)
  LEAVE_CHAT_MESSAGE = new('whiteboard_chat', 'Leave a chat message on a whiteboard', 0)

  class << self
    private :new
  end

end
