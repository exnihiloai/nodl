require "test_helper"
require "stringio"
require "nodl/cli"

class NodlCliTest < ActiveSupport::TestCase
  test "prints a useful error when command is missing" do
    output = StringIO.new
    error_output = StringIO.new

    status = Nodl::Cli.new([], output: output, error_output: error_output).call

    assert_equal 1, status
    assert_includes error_output.string, "Command is required"
    assert_includes error_output.string, "bin/nodl run AUDIO_PATH"
  end

  test "prints a useful error when audio path is missing" do
    output = StringIO.new
    error_output = StringIO.new

    status = Nodl::Cli.new([ "run" ], output: output, error_output: error_output).call

    assert_equal 1, status
    assert_includes error_output.string, "Audio file path is required"
  end
end
