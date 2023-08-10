class EJX::Template::BalanceScanner
  include StreamParser

  BALANCE = {
    "}" => "{",
    ")" => "(",
    "{" => "}",
    "(" => ")",
  }
    
  def parse(stack = [])
    while !eos?
      if match = scan_until(/[\(\)\{\}\"\'\`]/)
        case match[0]
        when "}", ")"
          if stack.last == BALANCE[match[0]]
            stack.pop
          else
            stack << match[0]
          end
        when "\"", "'", "`"
          quoted_value(match[0])
        else
          stack << match[0]
        end
      end
    end
    
    stack
  end

end
