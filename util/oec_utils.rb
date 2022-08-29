require_relative 'spec_helper'

class OecUtils

  include Logging

  @config = Utils.config

  def self.base_url(args = nil)
    (args && args.include?('qa')) ? 'https://course-evaluations-qa.berkeley.edu' : 'https://course-evaluations.berkeley.edu'
  end

  def self.create_results_file
    output_dir = File.join(ENV['HOME'], 'selenium-files')
    output_file = 'data_source_update_results.log'
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    file = File.join(output_dir, output_file)
    File.open(file, 'w') { |f| f.puts 'Results of OEC data source update script run:' }
    file
  end

  def self.log_results(file, result, e = nil)
    puts result
    puts "#{e.message}\n#{e.backtrace}" if e
    File.open(file, 'a') do |f|
      f.puts "\n => #{result}"
      f.puts "\n#{e.message}\n#{e.backtrace}" if e
    end
  end

  # Returns identifiers for a configured OEC test user
  # @return [Hash]
  def self.oec_user
    {
      first_name: @config['oec']['first_name'],
      last_name: @config['oec']['last_name'],
      uid: @config['oec']['uid'],
      sis_id: @config['oec']['sis_id'],
      email: @config['oec']['email']
    }
  end

end
