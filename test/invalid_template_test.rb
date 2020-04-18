require 'test_helper'

class InvalidTemplateTest < Minitest::Test

  test "mismatched closing tag" do
    e = assert_raises EJX::TemplateError do
      EJX.compile(<<~DATA)
        <div>
          <input type="submit" />
        </test>
      DATA
    end
    
    assert_equal <<~MSG.strip, e.message
    Expected to close div tag, instead closed test
       3: </test>
          --^^^^
    MSG
  end
  
end