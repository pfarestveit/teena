class SquiggyCategory

  attr_accessor :id, :name

  def initialize(name)
    @name = name
  end

  def set_id
    query = "SELECT id FROM categories WHERE title = '#{@name}'"
    @id = Utils.query_pg_db_field(SquiggyUtils.db_credentials, query, 'id').first
  end

end
