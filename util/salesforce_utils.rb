require_relative 'spec_helper'

class SalesforceUtils < Utils

  @config = Utils.config['salesforce']

  def self.base_url
    @config['base_url']
  end

  def self.login_credentials
    {
      :username => @config['username'],
      :password => @config['password']
    }
  end

end
