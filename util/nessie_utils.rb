require_relative 'spec_helper'

class NessieUtils < Utils

  @config = Utils.config['nessie']

  def self.nessie_pg_db_credentials
    {
      :host => @config['pg_db_host'],
      :port => @config['pg_db_port'],
      :name => @config['pg_db_name'],
      :user => @config['pg_db_user'],
      :password => @config['pg_db_password']
    }
  end
end
