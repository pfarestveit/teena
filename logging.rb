require_relative 'util/spec_helper'
require 'logger'

module Logging

  class << self
    def logger
      log_file = Utils.log_file
      @logger ||= Logger.new(log_file)
    end

    def logger=(logger)
      @logger = logger
    end
  end

  def self.included(base)
    class << base
      def logger
        Logging.logger
      end
    end
  end

  def logger
    Logging.logger
  end
end
