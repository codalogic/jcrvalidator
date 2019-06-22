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

require 'jcr/parser'
require 'jcr/map_rule_names'
require 'jcr/check_groups'
require 'jcr/evaluate_rules'
require 'jcr/name_association'

module JCR

  class ObjectBehavior
    attr_accessor :name_association, :name_key_tally

    def initialize
      @name_association = NameAssociation.new
      @name_key_tally = Hash.new 0
    end
  end

  def self.evaluate_object_rule jcr, rule_atom, data, econs, behavior = nil, target_annotations = nil

    push_trace_stack( econs, jcr )
    if behavior
      trace( econs, "Evaluating group in object rule starting at #{slice_to_s(jcr)} against", data )
      trace_def( econs, "object group", jcr, data )
    else
      trace( econs, "Evaluating object rule starting at #{slice_to_s(jcr)} against", data )
      trace_def( econs, "object", jcr, data )
    end
    retval = evaluate_object( jcr, rule_atom, data, econs, behavior, target_annotations )
    if behavior
      trace_eval( econs, "Object group", retval, jcr, data, "object" )
    else
      trace_eval( econs, "Object", retval, jcr, data, "object" )
    end
    pop_trace_stack( econs )
    return retval

  end

  def self.evaluate_object jcr, rule_atom, data, econs, behavior = nil, target_annotations = nil

    rules, annotations = get_rules_and_annotations( jcr )

    # if the data is not an object (Hash)
    return evaluate_not( annotations,
      Evaluation.new( false, "#{data} is not an object for #{raised_rule(jcr,rule_atom)}"),
                      econs, target_annotations ) unless data.is_a? Hash

    # if the object has no zero sub-rules it will accept anything due to being open for extension
    return evaluate_not( annotations,
      Evaluation.new( true, nil ), econs, target_annotations ) if rules.empty?

    retval = nil
    if ! behavior
      behavior = ObjectBehavior.new
      # Compute set of present JCR name keys
      JCR.each_member( rules, econs ) { |r| behavior.name_association.add_rule_name r }
      # Tally number of JSON names associated with each JCR name key
      data.each_key { |name| behavior.name_key_tally[behavior.name_association.key_from_json(name)] += 1 }
    end

    if JCR.is_choice rules
      if rules.length > 0 && rules[0][:_excluded_name_keys] == nil  # If exclusions not already computed
        all_name_keys = Set.new
        JCR.each_non_excluded_member( rules, econs ) do |r|
          all_name_keys << r[:_member_name_key]
        end
        rules.each do |sub_rule|
          sub_name_keys = Set.new
          JCR.each_non_excluded_member( sub_rule, econs ) { |r| sub_name_keys << r[:_member_name_key] }
          sub_rule[:_excluded_name_keys] = all_name_keys - sub_name_keys
        end
      end
    end

    rules.each do |rule|

      # short circuit logic
      if rule[:choice_combiner] && retval && retval.success
        next
      elsif rule[:sequence_combiner] && retval && !retval.success
        return evaluate_not( annotations, retval, econs, target_annotations ) # short circuit
      end

      has_excluded_name_keys = false
      if rule[:_excluded_name_keys]
        data.each_key do |json_name|
          name_key = behavior.name_association.key_from_json json_name
          if rule[:_excluded_name_keys].include?( name_key )
            retval = Evaluation.new( false, "JSON name #{json_name} excluded from rule #{jcr_to_s(rule)} in choice #{jcr_to_s(rules)}")
            has_excluded_name_keys = true
          end
        end
      end

      next if has_excluded_name_keys

      repeat_min, repeat_max, repeat_step = get_repetitions( rule, econs )

      grule,gtarget_annotations = get_group_or_object_mixin(rule, econs)

      if grule  # if a sub-group

        if repeat_max == 0
          if has_instances_from_group( grule, econs, behavior )
            retval = Evaluation.new( false, "object instance contains members of disallowed sub-group #{jcr_to_s(rule)} for #{raised_rule(jcr,rule_atom)}")
          end
        elsif repeat_max > 1 || repeat_step > 1
          retval = Evaluation.new( false, "sub-group in object can not have max repetitions greater than 1: #{jcr_to_s(rule)} for #{raised_rule(jcr,rule_atom)}")
        else
          retval = evaluate_rule( grule, rule_atom, data, econs, behavior, gtarget_annotations )

          if ! retval.success
            if repeat_min == 0
              # Can pass a failing sub-group if all its members are not present in the JSON instance
              if has_instances_from_group( grule, econs, behavior )
                retval = Evaluation.new( false, "object instance contains some but not all necessary parts of optional group #{jcr_to_s(rule)} for #{raised_rule(jcr,rule_atom)}")
              else
                retval = Evaluation.new( true, nil )
              end
            else
              retval = Evaluation.new( false, "object does not contain group #{jcr_to_s(rule)} for #{raised_rule(jcr,rule_atom)}")
            end
          else
            retval = Evaluation.new( true, nil )
          end
        end

      else # if not grule

        lookahead, ltarget_annotations = get_leaf_rule( rule, econs )
        lrules, lannotations = get_rules_and_annotations( lookahead[:member_rule] )
        rule_name_key = NameAssociation.key lrules[0]
        num_passes = 0
        has_failed_value_match = false

        data.each do |json_name, json_value|
          json_name_key = behavior.name_association.key_from_json json_name
          if json_name_key == rule_name_key
            retval = evaluate_rule(rule, rule_atom, [false, json_value], econs, nil, nil)
            if retval.success
              num_passes += 1
            else
              has_failed_value_match = true
              break
            end
          end
        end

        next if has_failed_value_match

        trace( econs, "Found #{num_passes} matching members repetitions in object with min #{repeat_min} and max #{repeat_max}" )
        if num_passes == 0 && repeat_min > 0
          retval = Evaluation.new( false, "object does not contain #{jcr_to_s(rule)} for #{raised_rule(jcr,rule_atom)}")
        elsif num_passes < repeat_min
          retval = Evaluation.new( false, "object does not have enough #{jcr_to_s(rule)} for #{raised_rule(jcr,rule_atom)}")
        elsif num_passes > repeat_max
          retval = Evaluation.new( false, "object has too many #{jcr_to_s(rule)} for #{raised_rule(jcr,rule_atom)}")
        elsif repeat_step && ( num_passes - repeat_min ) % repeat_step != 0
          retval = Evaluation.new( false, "object matches (#{num_passes}) does not match repetition step of #{repeat_max} & #{repeat_step} for #{jcr_to_s(rule)} for #{raised_rule(jcr,rule_atom)}")
        else
          retval = Evaluation.new( true, nil)
        end

        retval = evaluate_not( lannotations, retval, econs )

      end # end if grule else

    end # end rules.each

    return evaluate_not( annotations, retval, econs, target_annotations )
  end

  def self.has_instances_from_group( grule, econs, behavior )
    each_non_excluded_member( grule, econs ) { |r| return true if behavior.name_key_tally[NameAssociation.key( r )] > 0 }
    false
  end

  def self.object_to_s( jcr, shallow=true )
    rules, annotations = get_rules_and_annotations( jcr )
    return "#{annotations_to_s( annotations)}{ #{rules_to_s(rules,shallow)} }"
  end
end
