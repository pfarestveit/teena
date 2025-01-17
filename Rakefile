require_relative 'util/spec_helper'

begin

  # These opts will show test progress in the terminal as well as output the results to a file. VERSION is not required and
  # should include the service and code version in a recognizable format (e.g., 'junction-v91' or 'suitec-v2.2'), which
  # will be included in the test results file name.

  opts = "--format progress --format documentation --out #{Utils.test_results ENV['VERSION']} --no-color"

  # These tasks will run all test scripts for a given service, unless SCRIPTS is included. If a SCRIPTS string is included, then
  # it will run only scripts whose file names include the string.

  def run_specs(task, dir_str, opts)
    task.pattern = ENV['SCRIPTS'] ? "spec/#{dir_str}/*#{ENV['SCRIPTS']}*" : "spec/#{dir_str}/*"
    task.rspec_opts = opts
  end

  task default: :ripley
  RSpec::Core::RakeTask.new(:ripley) { |t| run_specs(t, 'ripley', opts) }

  task default: :squiggy
  RSpec::Core::RakeTask.new(:squiggy) { |t| run_specs(t, 'squiggy', opts) }

end
