# Copyright (c) 2015-2016 American Registry for Internet Numbers
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

require 'ipaddr'
require 'time'
require 'addressable/uri'
require 'addressable/template'
require 'email_address_validator'
require 'big-phoney'

require 'jcr/parser'
require 'jcr/map_rule_names'
require 'jcr/check_groups'

module JCR

  def self.evaluate_value_rule jcr, rule_atom, data, econs, behavior, target_annotations

    push_trace_stack( econs, jcr )
    trace( econs, "Evaluating value rule starting at #{slice_to_s(jcr)}" )
    trace_def( econs, "value", jcr, data )

    retval = evaluate_values( jcr, rule_atom, data, econs )

    _, annotations = get_rules_and_annotations( jcr )
    retval = evaluate_not( annotations, retval,
                           econs, target_annotations )
    trace_eval( econs, "Value", retval, jcr, data, "value")
    pop_trace_stack( econs )
    return retval
  end

  def self.evaluate_values jcr, rule_atom, data, econs
    rules, annotations = get_rules_and_annotations( jcr )

    has_exclude_min = has_annotation annotations, :exclude_min_annotation
    has_exclude_max = has_annotation annotations, :exclude_max_annotation
    rule = rules[0]

    case

      #
      # any
      #

      when rule[:any]
        return Evaluation.new( true, nil )

      #
      # integers
      #

      when rule[:integer_v]
        si = rule[:integer_v].to_s
        if si == "integer"
          return bad_value( rule, rule_atom, "integer", data ) unless data.is_a?( Integer )
        end
      when rule[:integer]
        i = rule[:integer].to_s.to_i
        return bad_value( rule, rule_atom, i, data ) unless data == i
      when rule[:integer_min] != nil && rule[:integer_max] == nil
        return bad_value( rule, rule_atom, "integer", data ) unless data.is_a?( Integer )
        min = rule[:integer_min].to_s.to_i
        return bad_value( rule, rule_atom, min, data ) unless min_cmp( data, min, has_exclude_min )
      when rule[:integer_min] == nil && rule[:integer_max] != nil
        return bad_value( rule, rule_atom, "integer", data ) unless data.is_a?( Integer )
        max = rule[:integer_max].to_s.to_i
        return bad_value( rule, rule_atom, max, data ) unless max_cmp( data, max, has_exclude_max )
      when rule[:integer_min],rule[:integer_max]
        return bad_value( rule, rule_atom, "integer", data ) unless data.is_a?( Integer )
        min = rule[:integer_min].to_s.to_i
        return bad_value( rule, rule_atom, min, data ) unless min_cmp( data, min, has_exclude_min )
        max = rule[:integer_max].to_s.to_i
        return bad_value( rule, rule_atom, max, data ) unless max_cmp( data, max, has_exclude_max )
      when rule[:sized_int_v]
        bits = rule[:sized_int_v][:bits].to_i
        return bad_value( rule, rule_atom, "int" + bits.to_s, data ) unless data.is_a?( Integer )
        min = -(2**(bits-1))
        return bad_value( rule, rule_atom, min, data ) unless min_cmp( data, min, has_exclude_min )
        max = 2**(bits-1)-1
        return bad_value( rule, rule_atom, max, data ) unless max_cmp( data, max, has_exclude_max )
      when rule[:sized_uint_v]
        bits = rule[:sized_uint_v][:bits].to_i
        return bad_value( rule, rule_atom, "int" + bits.to_s, data ) unless data.is_a?( Integer )
        min = 0
        return bad_value( rule, rule_atom, min, data ) unless min_cmp( data, min, has_exclude_min )
        max = 2**bits-1
        return bad_value( rule, rule_atom, max, data ) unless max_cmp( data, max, has_exclude_max )

      #
      # floats
      #

      when rule[:float_v]
        sf = rule[:float_v].to_s
        if sf == "float"
          return bad_value( rule, rule_atom, "float", data ) unless data.is_a?( Float )
        end
      when rule[:float]
        f = rule[:float].to_s.to_f
        return bad_value( rule, rule_atom, f, data ) unless data == f
      when rule[:float_min] != nil && rule[:float_max] == nil
        return bad_value( rule, rule_atom, "float", data ) unless data.is_a?( Float )
        min = rule[:float_min].to_s.to_f
        return bad_value( rule, rule_atom, min, data ) unless min_cmp( data, min, has_exclude_min )
      when rule[:float_min] == nil && rule[:float_max] != nil
        return bad_value( rule, rule_atom, "float", data ) unless data.is_a?( Float )
        max = rule[:float_max].to_s.to_f
        return bad_value( rule, rule_atom, max, data ) unless max_cmp( data, max, has_exclude_max )
      when rule[:float_min],rule[:float_max]
        return bad_value( rule, rule_atom, "float", data ) unless data.is_a?( Float )
        min = rule[:float_min].to_s.to_f
        return bad_value( rule, rule_atom, min, data ) unless min_cmp( data, min, has_exclude_min )
        max = rule[:float_max].to_s.to_f
        return bad_value( rule, rule_atom, max, data ) unless max_cmp( data, max, has_exclude_max )
      when rule[:double_v]
        sf = rule[:double_v].to_s
        if sf == "double"
          return bad_value( rule, rule_atom, "double", data ) unless data.is_a?( Float )
        end

      #
      # boolean
      #

      when rule[:true_v]
        return bad_value( rule, rule_atom, "true", data ) unless data
      when rule[:false_v]
        return bad_value( rule, rule_atom, "false", data ) if data
      when rule[:boolean_v]
        return bad_value( rule, rule_atom, "boolean", data ) unless ( data.is_a?( TrueClass ) || data.is_a?( FalseClass ) )

      #
      # strings
      #

      when rule[:string]
        return bad_value( rule, rule_atom, "string", data ) unless data.is_a? String
      when rule[:q_string]
        s = rule[:q_string].to_s
        return bad_value( rule, rule_atom, s, data ) unless data == s

      #
      # regex
      #

      when rule[:regex]
        regex = Regexp.new( rule[:regex].to_s )
        return bad_value( rule, rule_atom, regex, data ) unless data.is_a? String
        return bad_value( rule, rule_atom, regex, data ) unless data =~ regex

      #
      # ip addresses
      #

      when rule[:ipv4]
        return bad_value( rule, rule_atom, "IPv4 Address", data ) unless data.is_a? String
        begin
          ip = IPAddr.new( data )
        rescue IPAddr::InvalidAddressError
          return bad_value( rule, rule_atom, "IPv4 Address", data )
        end
        return bad_value( rule, rule_atom, "IPv4 Address", data ) unless ip.ipv4?
      when rule[:ipv6]
        return bad_value( rule, rule_atom, "IPv6 Address", data ) unless data.is_a? String
        begin
          ip = IPAddr.new( data )
        rescue IPAddr::InvalidAddressError
          return bad_value( rule, rule_atom, "IPv6 Address", data )
        end
        return bad_value( rule, rule_atom, "IPv6 Address", data ) unless ip.ipv6?
      when rule[:ipaddr]
        return bad_value( rule, rule_atom, "IP Address", data ) unless data.is_a? String
        begin
          ip = IPAddr.new( data )
        rescue IPAddr::InvalidAddressError
          return bad_value( rule, rule_atom, "IP Address", data )
        end
        return bad_value( rule, rule_atom, "IP Address", data ) unless ip.ipv6? || ip.ipv4?

      #
      # domain names
      #

      when rule[:fqdn]
        return bad_value( rule, rule_atom, "Fully Qualified Domain Name", data ) unless data.is_a? String
        return bad_value( rule, rule_atom, "Fully Qualified Domain Name", data ) if data.empty?
        a = data.split( '.' )
        a.each do |label|
          return bad_value( rule, rule_atom, "Fully Qualified Domain Name", data ) if label.start_with?( '-' )
          return bad_value( rule, rule_atom, "Fully Qualified Domain Name", data ) if label.end_with?( '-' )
          label.each_char do |char|
            unless (char >= 'a' && char <= 'z') \
              || (char >= 'A' && char <= 'Z') \
              || (char >= '0' && char <='9') \
              || char == '-'
              return bad_value( rule, rule_atom, "Fully Qualified Domain Name", data )
            end
          end
        end
      when rule[:idn]
        return bad_value( rule, rule_atom, "Internationalized Domain Name", data ) unless data.is_a? String
        return bad_value( rule, rule_atom, "Internationalized Domain Name", data ) if data.empty?
        a = data.split( '.' )
        a.each do |label|
          return bad_value( rule, rule_atom, "Internationalized Domain Name", data ) if label.start_with?( '-' )
          return bad_value( rule, rule_atom, "Internationalized Domain Name", data ) if label.end_with?( '-' )
          label.each_char do |char|
            unless (char >= 'a' && char <= 'z') \
              || (char >= 'A' && char <= 'Z') \
              || (char >= '0' && char <='9') \
              || char == '-' \
              || char.ord > 127
              return bad_value( rule, rule_atom, "Internationalized Domain Name", data )
            end
          end
        end

      #
      # uri and uri scheme
      #

      when rule[:uri]
        if rule[:uri].is_a? Hash
          t = rule[:uri][:uri_scheme].to_s
          return bad_value( rule, rule_atom, t, data ) unless data.is_a? String
          return bad_value( rule, rule_atom, t, data ) unless data.start_with?( t )
        else
          return bad_value( rule, rule_atom, "URI", data ) unless data.is_a?( String )
          uri = Addressable::URI.parse( data )
          return bad_value( rule, rule_atom, "URI", data ) unless uri.is_a?( Addressable::URI )
        end

      #
      # phone and email value rules
      #

      when rule[:email]
        return bad_value( rule, rule_atom, "Email Address", data ) unless data.is_a? String
        return bad_value( rule, rule_atom, "Email Address", data ) unless EmailAddressValidator.validate( data, true )

      when rule[:phone]
        return bad_value( rule, rule_atom, "Phone Number", data ) unless data.is_a? String
        p = BigPhoney::PhoneNumber.new( data )
        return bad_value( rule, rule_atom, "Phone Number", data ) unless p.valid?

      #
      # hex values
      #

      when rule[:hex]
        return bad_value( rule, rule_atom, "Hex Data", data ) unless data.is_a? String
        return bad_value( rule, rule_atom, "Hex Data", data ) unless data.length % 2 == 0
        pad_start = false
        data.each_char do |char|
          unless (char >= '0' && char <='9') \
              || (char >= 'A' && char <= 'F') \
              || (char >= 'a' && char <= 'f')
            return bad_value( rule, rule_atom, "Hex Data", data )
          end
        end

      #
      # base32hex values
      #

      when rule[:base32hex]
        return bad_value( rule, rule_atom, "Base32hex Data", data ) unless data.is_a? String
        return bad_value( rule, rule_atom, "Base32hex Data", data ) unless data.length % 8 == 0
        pad_start = false
        data.each_char do |char|
          if char == '='
            pad_start = true
          elsif pad_start && char != '='
            return bad_value( rule, rule_atom, "Base32hex Data", data )
          else 
              unless (char >= '0' && char <='9') \
                  || (char >= 'A' && char <= 'V') \
                  || (char >= 'a' && char <= 'v')
                return bad_value( rule, rule_atom, "Base32hex Data", data )
              end
          end
        end

      #
      # base32 values
      #

      when rule[:base32]
        return bad_value( rule, rule_atom, "Base 32 Data", data ) unless data.is_a? String
        return bad_value( rule, rule_atom, "Base 32 Data", data ) unless data.length % 8 == 0
        pad_start = false
        data.each_char do |char|
          if char == '='
            pad_start = true
          elsif pad_start && char != '='
            return bad_value( rule, rule_atom, "Base 32 Data", data )
          else 
              unless (char >= 'a' && char <= 'z') \
                  || (char >= 'A' && char <= 'Z') \
                  || (char >= '2' && char <='7')
                return bad_value( rule, rule_atom, "Base 32 Data", data )
              end
          end
        end

      #
      # base64url values
      #

      when rule[:base64url]
        return bad_value( rule, rule_atom, "Base64url Data", data ) unless data.is_a? String
        return bad_value( rule, rule_atom, "Base64url Data", data ) unless data.length % 4 == 0
        pad_start = false
        data.each_char do |char|
          if char == '='
            pad_start = true
          elsif pad_start && char != '='
            return bad_value( rule, rule_atom, "Base64url Data", data )
          else 
              unless (char >= 'a' && char <= 'z') \
                  || (char >= 'A' && char <= 'Z') \
                  || (char >= '0' && char <='9') \
                  || char == '-' || char == '_'
                return bad_value( rule, rule_atom, "Base64url Data", data )
              end
          end
        end

      #
      # base64 values
      #

      when rule[:base64]
        return bad_value( rule, rule_atom, "Base 64 Data", data ) unless data.is_a? String
        return bad_value( rule, rule_atom, "Base 64 Data", data ) unless data.length % 4 == 0
        pad_start = false
        data.each_char do |char|
          if char == '='
            pad_start = true
          elsif pad_start && char != '='
            return bad_value( rule, rule_atom, "Base 64 Data", data )
          else 
              unless (char >= 'a' && char <= 'z') \
                  || (char >= 'A' && char <= 'Z') \
                  || (char >= '0' && char <='9') \
                  || char == '+' || char == '/'
                return bad_value( rule, rule_atom, "Base 64 Data", data )
              end
          end
        end

      #
      # time and date values
      #

      when rule[:datetime]
        return bad_value( rule, rule_atom, "Time and Date", data ) unless data.is_a? String
        begin
          Time.iso8601( data )
        rescue ArgumentError
          return bad_value( rule, rule_atom, "Time and Date", data )
        end
      when rule[:date]
        return bad_value( rule, rule_atom, "Date", data ) unless data.is_a? String
        begin
          d = data + "T23:20:50.52Z"
          Time.iso8601( d )
        rescue ArgumentError
          return bad_value( rule, rule_atom, "Date", data )
        end
      when rule[:time]
        return bad_value( rule, rule_atom, "Time", data ) unless data.is_a? String
        begin
          t = "1985-04-12T" + data + "Z"
          Time.iso8601( t )
        rescue ArgumentError
          return bad_value( rule, rule_atom, "Time", data )
        end

      #
      # null
      #

      when rule[:null]
        return bad_value( rule, rule_atom, nil, data ) unless data == nil

      #
      # groups
      #

      when rule[:group_rule]
        return evaluate_group_rule rule[:group_rule], rule_atom, data, econs

      else
        raise "unknown value rule evaluation. this shouldn't happen"
    end
    return Evaluation.new( true, nil )
  end

  def self.min_cmp data, min, is_min_excluded
    return data > min if is_min_excluded
    return data >= min
  end

  def self.max_cmp data, min, is_max_excluded
    return data < min if is_max_excluded
    return data <= min
  end

  def self.bad_value jcr, rule_atom, expected, actual
    Evaluation.new( false, "expected << #{expected} >> but got << #{actual} >> for #{raised_rule(jcr,rule_atom)}" )
  end

  def self.value_to_s( jcr, shallow=true )

    rules, annotations = get_rules_and_annotations( jcr )

    rule = rules[ 0 ]
    retval = ""
    case

      when rule[:any]
        retval =  "any"

      when rule[:integer_v]
        retval =  rule[:integer_v].to_s
      when rule[:integer]
        retval =  rule[:integer].to_s.to_i
      when rule[:integer_min],rule[:integer_max]
        min = "-INF"
        max = "INF"
        min = rule[:integer_min].to_s.to_i if rule[:integer_min]
        max = rule[:integer_max].to_s.to_i if rule[:integer_max]
        retval =  "#{min}..#{max}"
      when rule[:sized_int_v]
        retval =  "int" + rule[:sized_int_v][:bits].to_s
      when rule[:sized_uint_v]
        retval =  "uint" + rule[:sized_uint_v][:bits].to_s

      when rule[:double_v]
        retval =  rule[:double_v].to_s
      when rule[:float_v]
        retval =  rule[:float_v].to_s
      when rule[:float]
        retval =  rule[:float].to_s.to_f
      when rule[:float_min],rule[:float_max]
        min = "-INF"
        max = "INF"
        min = rule[:float_min].to_s.to_f if rule[:float_min]
        max = rule[:float_max].to_s.to_f if rule[:float_max]
        retval =  "#{min}..#{max}"

      when rule[:true_v]
        retval =  "true"
      when rule[:false_v]
        retval =  "false"
      when rule[:boolean_v]
        retval =  "boolean"

      when rule[:string]
        retval =  "string"
      when rule[:q_string]
        retval =  %Q|"#{rule[:q_string].to_s}"|

      when rule[:regex]
        retval =  "/#{rule[:regex].to_s}/"

      when rule[:ipv4]
        retval =  "ipv4"
      when rule[:ipv6]
        retval =  "ipv6"

      when rule[:fqdn]
        retval =  "fqdn"
      when rule[:idn]
        retval =  "idn"

      when rule[:uri]
        if rule[:uri].is_a? Hash
          retval =  "uri..#{rule[:uri][:uri_scheme].to_s}"
        else
          retval =  "uri"
        end

      when rule[:email]
        retval =  "email"

      when rule[:phone]
        retval =  "phone"

      when rule[:hex]
        retval =  "hex"
      when rule[:base32hex]
        retval =  "base32hex"
      when rule[:base64url]
        retval =  "base64url"
      when rule[:base64]
        retval =  "base64"

      when rule[:datetime]
        retval =  "datetime"
      when rule[:date]
        retval =  "date"
      when rule[:time]
        retval =  "time"

      when rule[:null]
        retval =  "null"

      when rule[:group_rule]
        retval =  group_to_s( rule[:group_rule], shallow )

      else
        retval =  "** unknown value rule **"
    end
    return annotations_to_s( annotations ) + retval.to_s
  end

end
