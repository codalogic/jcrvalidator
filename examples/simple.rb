# Copyright (C) 2015 American Registry for Internet Numbers (ARIN)
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
# IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# This example demonstrates using the JCR Validator with a ruleset to
# evaluate two different sets of JSON data

require 'jcr'

ruleset = <<RULESET
# ruleset-id rfcXXXX
# jcr-version 0.7

[ $my_integers *2, $my_strings *2 ]
$my_integers =: 0..2
$my_strings =: ( "foo" | "bar" )

RULESET

# Create a JCR context.
# This is done for effeciency sake when evaluating multiple JSON
begin
  ctx = JCR::Context.new( ruleset )
rescue Parslet::ParseFailed => failure
  # if the JCR fails to parse, this will be thrown
  puts failure.parse_failure_cause.ascii_tree unless options[:quiet]
  return 1
end

# Evaluate the first JSON
data1 = JSON.parse( '[ 1, 2, "foo", "bar" ]')
e1 = ctx.evaluate( data1 )
# Should be true
puts "Ruleset evaluation of JSON = " + e1.success.to_s

data2 = JSON.parse( '[ 2, 1, "bar", "foo" ]')
e2 = ctx.evaluate( data2 )
# Should be true
puts "Ruleset evaluation of JSON = " + e2.success.to_s

# return the evaluations as an exit code
exit e1.success && e2.success


