require_relative 'util/spec_helper'

begin

  # These opts will show test progress in the terminal as well as output the results to a file. VERSION is not required and
  # should include the service and code version in a recognizable format (e.g., 'junction-v91' or 'suitec-v2.2'), which
  # will be included in the test results file name.

  opts = "--format progress --format documentation --out #{Utils.test_results ENV['VERSION']}"

  # The following two tasks are for executing all SuiteC test scripts divided between two threads in order to reduce total
  # execution time.

  task default: :suitec_thread_1
  RSpec::Core::RakeTask.new(:suitec_thread_1) do |t|
    t.pattern = 'spec/suitec/asset_library*_spec.rb, spec/suitec/engagement_index*_spec.rb'
    t.rspec_opts = opts
  end

  task default: :suitec_thread_2
  RSpec::Core::RakeTask.new(:suitec_thread_2) do |t|
    t.pattern = 'spec/suitec/whiteboard*_spec.rb, spec/suitec/canvas*_spec.rb, spec/suitec/impact_studio*_spec.rb'
    t.rspec_opts = opts
  end

  # The following is for executing all Junction test scripts on a single thread.

  task default: :junction
  RSpec::Core::RakeTask.new(:junction) do |t|
    t.pattern = 'spec/junction/*_spec.rb'
    t.rspec_opts = opts
  end

  # The following is for running a single test script or group of scripts for SuiteC, Junction, or BOAC
  # (e.g., 'junction/canvas_lti_mailing_lists' or 'suitec/impact_studio').

  task default: :scripts
  RSpec::Core::RakeTask.new(:scripts) do |t|
    t.pattern = "spec/#{ENV['SCRIPTS']}*_spec.rb"
    t.rspec_opts = opts
  end

  # The following is for running the OEC test to verify that Blue evaluation forms (fill out) contain the expected questions

  task default: :oec
  RSpec::Core::RakeTask.new(:oec) do |t|
    t.pattern = 'spec/oec/oec_form_fill_out_spec.rb'
    t.rspec_opts = opts
  end

end
