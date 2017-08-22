class EventType

  attr_accessor :desc

  def initialize(desc)
    @desc = desc
  end

  EVENT_TYPES = [
      ADD = new('Added'),
      CREATE = new('Created'),
      DELETE = new('Deleted'),
      HIDE = new('Hid'),
      LIKE = new('Liked'),
      MODIFY = new('Modified'),
      NAVIGATE = new('NavigatedTo'),
      POST = new('Posted'),
      REMOVE = new('Removed'),
      RETRIEVE = new('Retrieved'),
      SEARCH = new('Searched'),
      SHARE = new('Shared'),
      SHOW = new('Showed'),
      VIEW = new('Viewed')
  ]

  class << self
    private :new
  end

end
