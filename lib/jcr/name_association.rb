# Copyright (c) 2015-2019 American Registry for Internet Numbers
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

module JCR

  class NameAssociation
    def initialize
      @json_to_key = {}
      @key_to_string_tester = {}
      @key_to_regex_tester = {}
      @key_to_wildcard_tester = {}
    end
    
    def add_rule_name rule
      k = NameAssociation.key rule
      if rule[:member_name]
        if ! @key_to_string_tester[k]
          @key_to_string_tester[k] = NameTesterString.new rule[:member_name][:q_string].to_s
        end
      elsif rule[:member_regex][:regex]
        if rule[:member_regex][:regex].is_a? Array
          if ! @key_to_wildcard_tester[k]
            @key_to_wildcard_tester[k] = NameTesterWildcard.new
          end
        else
          if ! @key_to_regex_tester[k]
            re_modifiers =
                    rule[:member_regex][:regex_modifiers].is_a?( Array ) ?
                    "" :
                    rule[:member_regex][:regex_modifiers].to_s
            @key_to_regex_tester[k] = NameTesterRegex.new rule[:member_regex][:regex], re_modifiers
          end
        end
      else
        raise JCR::JcrValidatorError, "Unrecognised member name format for rule: " + rule.to_s
      end
    end
    
    def key_from_json json_name
      res = @json_to_key[json_name]
      return res if res
      res = key_from_json_internal json_name
      @json_to_key[json_name] = res
      return res
    end
    
    private def key_from_json_internal json_name
      @key_to_string_tester.each { |k,v| return k if v.is_match json_name }

      re_matches = []
      @key_to_regex_tester.each { |k,v| re_matches.push( k ) if v.is_match json_name }
      return re_matches[0] if re_matches.length == 1
      raise JCR::JcrValidatorError, "JSON name: '#{json_name}' matches multiple name keys: #{re_matches}" if re_matches.length > 1

      @key_to_wildcard_tester.each { |k,v| return k if v.is_match json_name }
      return "" # Empty string == match not found
    end
    
    def self.key rule
      return rule[:_member_name_key] if rule[:_member_name_key]
      k = ''
      if rule[:member_name]
        k = "l" + rule[:member_name][:q_string].to_s
      elsif rule[:member_regex][:regex]
        if rule[:member_regex][:regex].is_a? Array
          k = "w"    # Wildcard = //
        else
          re_modifiers =
                  rule[:member_regex][:regex_modifiers].is_a?( Array ) ?
                  "" :
                  rule[:member_regex][:regex_modifiers].to_s
          k = "r" + re_modifiers + "/" + rule[:member_regex][:regex]
        end
      else
        raise JCR::JcrValidatorError, "Unrecognised member name format for rule: " + rule.to_s
      end
      rule[:_member_name_key] = k
      return k
    end
    
    class NameTesterString
      def initialize name
        @name = name
      end
      
      def is_match name
        @name == name
      end
    end
    
    class NameTesterRegex
      @@regex_cache = {}

      def initialize re, options
        re_key = options + "/" + re
        @regex = @@regex_cache[re_key]
        return if @regex
        
        re_options = 0
        if options != ""
          re_options |= Regexp::IGNORECASE if options.include? 'i'
          re_options |= Regexp::EXTENDED if options.include? 'x'
          re_options |= Regexp::MULTILINE if options.include? 's' # This maybe a Ruby specific option
        end
        @@regex_cache[re_key] = @regex = Regexp.new re, re_options
      end
      
      def is_match name
        @regex =~ name
      end
    end
    
    class NameTesterWildcard
      def initialize
      end
      
      def is_match name
        true
      end
    end
  end
end
