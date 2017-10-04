require_relative 'spec_helper'

class OecUtils

  include Logging

  @config = Utils.config

  def self.base_url(args)
    args.include?('qa') ? 'https://course-evaluations-qa.berkeley.edu' : 'https://course-evaluations.berkeley.edu'
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

end
