class Treetop::Runtime::SyntaxNode
	attr_reader :result
	@variables = [Hash.new]
	@replacements = Hash.new
	@temp = 0

	def var_exist? v
		variables.reverse_each do |vars|
			return vars[v] if vars[v]
		end
		false
	end

	def var_add v, temp = nil
		if $interactive
			variables[-1][v] = v
		else
			variables[-1][v] = temp
		end
	end

	def new_scope
		variables << Hash.new
	end

	def pop_scope
		variables.pop
	end

	def top_scope?
		variables.length == 1
	end

	def variables
		@@variables
	end

	def replacements
		@@replacements
	end

	def self.clear_variables
		@@variables = [Hash.new]
		@@temp = 0
	end

	def next_temp
		@result = "@temp#{@@temp += 1}"
	end

	def call_method object, method, arguments, arg_length
		temp = var_exist?(object) || object
		#"\n$print("Calling ", method, " on ", #{object}, " with (", #{arguments}, ")\\n");"
		<<-NEKO
		if(#{temp} == null) {
			$throw("Method invoked on null object.");
		}
		else {
			if(@brat.has_field(#{temp}, "#{method}")) {
				var arg_len = @brat.num_args(#{temp}, "#{method}");
				if(arg_len == -1 || arg_len == #{arg_length}) {
					$objcall(#{temp}, $hash("#{method}"), #{arguments});
				}	
				else
					$throw("Wrong number of arguments for " + @brat.nice_identifier("#{object}") + ".#{method}: should be " + $string(arg_len) + " but given #{arg_length}");
			}
			else if(@brat.has_field(#{temp}, "@#{arg_length}_#{method}")) {
				$objcall(#{temp}, $hash("@#{arg_length}_#{method}"), #{arguments});
			}
			else {
				$throw("Invoking undefined method #{method} on " + @brat.nice_identifier("#{object}"));
			}
		}
		NEKO
	end

	def get_value object, arguments, arg_length 
		temp = var_exist?(object) || object
		output = <<-NEKO
		if($typeof(#{temp}) == $tnull) {
			if(@brat.has_field(this, "#{object}")) {
		 		#{call_method("this", object, arguments, arg_length)}
			}
			else if(@brat.has_field(this, "@#{arg_length}_#{object}"))
		 		#{call_method("this", "@#{arg_length}_#{object}", arguments, arg_length)}
			else
			{
				$throw("Trying to invoke null method: " + @brat.nice_identifier("#{object}"));
			}
		} else {
			if($typeof(#{temp}) == $tfunction) {

				if(#{temp} == null) {
					$throw("Could not invoke null method: " + @brat.nice_identifier("#{object}"));
				}
			
				var arg_len = $nargs(#{temp});
				if(arg_len == -1 || arg_len == #{arg_length})
					$call(#{temp}, this, #{arguments});
				else
					$throw("Wrong number of arguments for " + @brat.nice_identifier("#{object}") + ". Expected " + $string(arg_len) + " but given #{arg_length}");
			}
		NEKO
		if arg_length > 0
			output << "else { $throw(\"Tried to invoke non-method: \" + @brat.nice_identifier(\"#{object}\")); }}"
		else
			output << "else { #{temp}; }}"
		end
	end

	def get_value_clean object, arguments, arg_length
		temp = var_exist?(object) || object
		<<-NEKO
		if($typeof(#{temp}) == $tnull) {
			if(@brat.has_field(this, "#{object}")) {
				#@result = $objget(this, $hash("#{object}"));
				
				var arg_len = $nargs(#@result);
				if(arg_len == -1 || arg_len == #{arg_length})
					#@result(#{arguments});
				else
					$throw("Wrong number of arguments for " + @brat.nice_identifier("#{object}") + ". Expected " + $string(arg_len) + " but given #{arg_length}");
			}
			else if(@brat.has_field(this, "@#{arg_length}_#{object}")) {
				#@result = $objget(this, $hash("@#{arg_length}_#{object}"));
				#@result(#{arguments});
			}
			else
			{
				$throw("Trying to invoke null method: " + @brat.nice_identifier("#{object}"));
			}
		} else {
			if($typeof(#{temp}) == $tfunction) {

				if(#{temp} == null) {
					$throw("Could not invoke null method:" + @brat.nice_identifier("#{object}"));
				}
			
				var arg_len = $nargs(#{temp});
				if(arg_len == -1 || arg_len == #{arg_length})
					#{temp}(#{arguments});
				else
					$throw("Wrong number of arguments for " + @brat.nice_identifier("#{object}") + ". Expected " + $string(arg_len) + " but given #{arg_length}");
			}
			else if(#{arg_length != 0 ? "true" : "false"}) {
				$throw("Tried to invoke non-method: " + @brat.nice_identifier("#{object}"));
			}
			else { 
				#{temp}; 
			}
		}
		NEKO
	end


	def invoke method, arguments, arg_length
		#\n$print("Calling ", #{method}, " with (", #{arguments}, ")\\n");
		temp = var_exist?(method) || method
		<<-NEKO
		if(#{temp} == null) {
			$throw("Could not invoke null method:" + @brat.nice_identifier("#{method}"));
		}
		else {
			var arg_len = $nargs(#{temp});
			if(arg_len == -1 || arg_len == #{arg_length})
				#{temp}(#{arguments});
			else
				$throw("Wrong number of arguments for " + @brat.nice_identifier("#{method}") + ". Expected " + $string(arg_len) + " but given #{arg_length}.");
		}
		NEKO
	end

	def escape_identifier identifier
		identifier.gsub(/([!?\-*+^&@~\/\\><$_%])/) do |e|
			case $1
			when "!"	
				"@bang"
			when "*"
				"@star"
			when "-"
				"@minus"
			when "+"
				"@plus"
			when "&"
				"@and"
			when "@"
				"@at"
			when "~"
				"@tilde"
			when "^"
				"@up"
			when "/"
				"@forward"
			when "\\"
				"@back"
			when "?"
				"@question"
			when "<"
				"@less"
			when ">"
				"@greater"
			when "$"
				"@dollar"
			when "_"
				"@under"
			when "%"
				"@percent"
			else
				nil	
			end
		end.gsub(/\b(true|false|if|then|else|do|while|break|continue|switch|default|null|var|try|catch|return|function|this)\b/i) {|m| "@" + $1 }
	end

	def escape_operator op
		op.gsub(/(!=|>=|<=|\|\||[!?\-*+^@~\/\\><$_%|&=])/) do
			case $1
			when "!"	
				"@bang"
			when "*"
				"@star"
			when "-"
				"@minus"
			when "+"
				"@plus"
			when "||"
				"@oror"
			when "|"
				"@or"
			when "&&"
				"@andand"
			when "&"
				"@and"
			when "@"
				"@at"
			when "~"
				"@tilde"
			when "^"
				"@up"
			when "/"
				"@forward"
			when "\\"
				"@back"
			when "?"
				"@question"
			when "<"
				"@less"
			when ">"
				"@greater"
			when "!="
				"@notequal"
			when "="
				"@equal"
			when ">="
				"@greater@equal"
			when "<="
				"@less@equal"
			when "%"
				"@percent"
			when "_"
				"@under"
			else
				"---something unmatched---"
			end
		end
	end
end
