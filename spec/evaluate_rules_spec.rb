# Copyright (C) 2015-2017 American Registry for Internet Numbers (ARIN)
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
require 'spec_helper'
require 'rspec'
require 'pp'
require_relative '../lib/jcr/evaluate_rules'
require_relative '../lib/jcr/name_association'

describe 'evaluate_rules' do

  #
  # repetition tests
  #

  it 'should see an optional as min 0 max 1' do
    tree = JCR.parse( '$trule=: [ string ? ]' )
    mapping = JCR.map_rule_names( tree )
    JCR.check_rule_target_names( tree, mapping )
    min, max = JCR.get_repetitions( tree[0][:rule][:array_rule], JCR::EvalConditions.new( nil, nil ) )
    expect( min ).to eq(0)
    expect( max ).to eq(1)
  end

  it 'should see a one or more as min 1 max infinity' do
    tree = JCR.parse( '$trule=: [ string + ]' )
    mapping = JCR.map_rule_names( tree )
    JCR.check_rule_target_names( tree, mapping )
    min, max = JCR.get_repetitions( tree[0][:rule][:array_rule], JCR::EvalConditions.new( nil, nil ) )
    expect( min ).to eq(1)
    expect( max ).to eq(Float::INFINITY)
  end

  it 'should see a zero or more as min 0 max infinity' do
    tree = JCR.parse( '$trule=: [ string * ]' )
    mapping = JCR.map_rule_names( tree )
    JCR.check_rule_target_names( tree, mapping )
    min, max = JCR.get_repetitions( tree[0][:rule][:array_rule], JCR::EvalConditions.new( nil, nil ) )
    expect( min ).to eq(0)
    expect( max ).to eq(Float::INFINITY)
  end

  it 'should see a 1 to 4 as min 1 max 4' do
    tree = JCR.parse( '$trule=: [ string *1..4 ]' )
    mapping = JCR.map_rule_names( tree )
    JCR.check_rule_target_names( tree, mapping )
    min, max = JCR.get_repetitions( tree[0][:rule][:array_rule], JCR::EvalConditions.new( nil, nil ) )
    expect( min ).to eq(1)
    expect( max ).to eq(4)
  end

  it 'should see 22 as min 22 max 22' do
    tree = JCR.parse( '$trule=: [ string *22 ]' )
    mapping = JCR.map_rule_names( tree )
    JCR.check_rule_target_names( tree, mapping )
    min, max = JCR.get_repetitions( tree[0][:rule][:array_rule], JCR::EvalConditions.new( nil, nil ) )
    expect( min ).to eq(22)
    expect( max ).to eq(22)
  end

  it 'should see nothing as min 1 max 1' do
    tree = JCR.parse( '$trule=: [ string ]' )
    mapping = JCR.map_rule_names( tree )
    JCR.check_rule_target_names( tree, mapping )
    min, max = JCR.get_repetitions( tree[0][:rule][:array_rule], JCR::EvalConditions.new( nil, nil ) )
    expect( min ).to eq(1)
    expect( max ).to eq(1)
  end

  #
  # each_member test
  #
  describe 'each_member' do

    it 'should iterate over each object member with no sub groups' do
      tree = JCR.parse( '{ "foo":string, "bar":string }' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lbar" ] )
    end

    it 'should iterate over each object member with sub groups' do
      tree = JCR.parse( '{ "foo":string, ("c1":string | "c2":string ), "bar":string }' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lc1", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with target member' do
      tree = JCR.parse( '{ "foo":string, ($tm1 | "c2":string ), "bar":string } $tm1 = "tm1":string' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltm1", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with target group' do
      tree = JCR.parse( '{ "foo":string, ($tg1 | "c2":string ), "bar":string } $tg1 = ("tg1":string, "tg2":string)' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltg1", "ltg2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with target object mixin' do
      tree = JCR.parse( '{ "foo":string, ($to1 | "c2":string ), "bar":string } $to1 = {"to1":string, "to2":string}' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lto1", "lto2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with double depth target groups' do
      tree = JCR.parse( '{ "foo":string, ($tg1 | "c2":string ), "bar":string } $tg1 = ("tg1":string, $tg2, "tg2":string) $tg2 = ("tg21":string)' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltg1", "ltg21", "ltg2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with recursive target groups' do
      tree = JCR.parse( '{ "foo":string, $tg1, "bar":string } $tg1 = ("tg1":string, ($tg1|"end":string))' ) # This is a contrived test case. Likely a user specification error
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltg1", "lend", "lbar" ] )
    end

  end

  #
  # each_non_excluded_member test
  #
  describe 'each_non_excluded_member' do

    it 'should iterate over each object member with no sub groups' do
      tree = JCR.parse( '{ "foo":string, "bar":string }' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lbar" ] )
    end

    it 'should iterate over each object member with no sub groups with 1 excluded' do
      tree = JCR.parse( '{ "foo":string *0, "bar":string }' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lbar" ] )
    end

    it 'should iterate over each object member with sub groups' do
      tree = JCR.parse( '{ "foo":string, ("c1":string | "c2":string ), "bar":string }' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lc1", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with sub groups with one excluded' do
      tree = JCR.parse( '{ "foo":string, ("c1":string | "c2":string *0 ), "bar":string }' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lc1", "lbar" ] )
    end

    it 'should iterate over each object member with target member' do
      tree = JCR.parse( '{ "foo":string, ($tm1 | "c2":string ), "bar":string } $tm1 = "tm1":string' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltm1", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with target member with target excluded' do
      tree = JCR.parse( '{ "foo":string, ($tm1 *0 | "c2":string ), "bar":string } $tm1 = "tm1":string' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with target group' do
      tree = JCR.parse( '{ "foo":string, ($tg1 | "c2":string ), "bar":string } $tg1 = ("tg1":string, "tg2":string)' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltg1", "ltg2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with target group with one excluded' do
      tree = JCR.parse( '{ "foo":string, ($tg1 | "c2":string ), "bar":string } $tg1 = ("tg1":string *0, "tg2":string)' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltg2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with target object mixin' do
      tree = JCR.parse( '{ "foo":string, ($to1 | "c2":string ), "bar":string } $to1 = {"to1":string, "to2":string}' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lto1", "lto2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with target object mixin with one excluded' do
      tree = JCR.parse( '{ "foo":string, ($to1 | "c2":string ), "bar":string } $to1 = {"to1":string *0, "to2":string}' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "lto2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with double depth target groups' do
      tree = JCR.parse( '{ "foo":string, ($tg1 | "c2":string ), "bar":string } $tg1 = ("tg1":string, $tg2, "tg2":string) $tg2 = ("tg21":string)' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltg1", "ltg21", "ltg2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with double depth target groups with oe excluded' do
      tree = JCR.parse( '{ "foo":string, ($tg1 | "c2":string ), "bar":string } $tg1 = ("tg1":string, $tg2, "tg2":string) $tg2 = ("tg21":string *0)' )
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltg1", "ltg2", "lc2", "lbar" ] )
    end

    it 'should iterate over each object member with recursive target groups' do
      tree = JCR.parse( '{ "foo":string, $tg1, "bar":string } $tg1 = ("tg1":string, ($tg1|"end":string))' ) # This is a contrived test case. Likely a user specification error
      mapping = JCR.map_rule_names( tree )
      JCR.check_rule_target_names( tree, mapping )
      names = []
      JCR.each_non_excluded_member( tree[0][:object_rule], JCR::EvalConditions.new( mapping, nil ) ) { |m| names << JCR::NameAssociation.key( m ) }
      expect( names ).to eq( [ "lfoo", "ltg1", "lend", "lbar" ] )
    end

  end

  #
  # get_annotation and has_annotation tests
  #

  it 'should return choice annotation with get_rules_and_annotations()' do
    tree = JCR.parse( '@{choice} @{not} { "foo":string, "bar":string }' )
    _, annotations = JCR.get_rules_and_annotations tree[0][:object_rule]
    expect( JCR.has_annotation( annotations, :choice_annotation ) ).to be_truthy
  end

  it 'should return choice annotation with get_rules_and_annotations()' do
    tree = JCR.parse( '@{choice} @{root} @{not} { "foo":string, "bar":string }' )
    _, annotations = JCR.get_rules_and_annotations tree[0][:object_rule]
    expect( JCR.has_annotation( annotations, :root_annotation ) ).to be_truthy
  end

  it 'should not return choice annotation with get_rules_and_annotations() when not present' do
    tree = JCR.parse( '@{not} { "foo":string, "bar":string }' )
    _, annotations = JCR.get_rules_and_annotations tree[0][:object_rule]
    expect( JCR.has_annotation( annotations, :choice_annotation ) ).to be_falsey
  end

  it 'should return choice annotation from a rule' do
    tree = JCR.parse( '@{not} @{choice} { "foo":string, "bar":string }' )
    expect( JCR.has_annotation( tree[0][:object_rule], :choice_annotation ) ).to be_truthy
  end

  it 'should return augments annotation from a rule' do
    tree = JCR.parse( '@{augments $foo} { "foo":string, "bar":string }' )
    augments_anno = JCR.get_annotation( tree[0][:object_rule], :augments_annotation )
    expect( augments_anno ).to be_truthy
  end

  #
  # is_choice tests
  #

  it 'should say true when is_choice() is called with a choice' do
    tree = JCR.parse( '{ "foo":string | "bar":string }' )
    expect( JCR.is_choice( tree[0][:object_rule] ) ).to be_truthy
  end

  it 'should say false when is_choice() is called with a sequence' do
    tree = JCR.parse( '{ "foo":string, "bar":string }' )
    expect( JCR.is_choice( tree[0][:object_rule] ) ).to be_falsey
  end

  it 'should say false when is_choice() is called with a single member object' do
    tree = JCR.parse( '{ "foo":string }' )
    expect( JCR.is_choice( tree[0][:object_rule] ) ).to be_falsey
  end

  it 'should say false when is_choice() is called with a empty object' do
    tree = JCR.parse( '{ }' )
    expect( JCR.is_choice( tree[0][:object_rule] ) ).to be_falsey
  end

  it 'should say true when is_choice() is called with a single member object with the @{choice} annotation' do
    tree = JCR.parse( '@{choice} { "foo":string }' )
    expect( JCR.is_choice( tree[0][:object_rule] ) ).to be_truthy
  end

  it 'should say true when is_choice() is called with a empty object with the @{choice} annotation' do
    tree = JCR.parse( '@{choice} { }' )
    expect( JCR.is_choice( tree[0][:object_rule] ) ).to be_truthy
  end

  #
  # plain text serialization
  #

  it 'should print out an array with a rule reference' do
    tree = JCR.parse( '[ $t ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( "[ $t ]")
  end

  it 'should print out an array with two strings anded in it' do
    tree = JCR.parse( '[ "foo", "bar" ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ "foo" , "bar" ]')
  end

  it 'should print out an array with two strings ored in it' do
    tree = JCR.parse( '[ "foo"| "bar" ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ "foo" | "bar" ]')
  end

  it 'should print out an array with primitives' do
    tree = JCR.parse( '[ "foo", 2, 2.3, true, false, null ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ "foo" , 2 , 2.3 , true , false , null ]')
  end

  it 'should print out an array with a regex' do
    tree = JCR.parse( '[ /foo*/ ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ /foo*/ ]')
  end

  it 'should print out an array with ranges' do
    tree = JCR.parse( '[ 0..1, 0.., ..2, 1.1..2.2, 2.2.., ..3.3 ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ 0..1 , 0..INF , -INF..2 , 1.1..2.2 , 2.2..INF , -INF..3.3 ]')
  end

  it 'should print out an array with primitive definitions' do
    tree = JCR.parse( '[ integer, string, float, double, any, boolean ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ integer , string , float , double , any , boolean ]')
  end

  it 'should print out sized int primitive definitions' do
    tree = JCR.parse( '[ int8, uint16 ]')
    expect( JCR.rule_to_s( tree[0] ) ).to eq('[ int8 , uint16 ]')
  end

  it 'should print out an array with other primitive definitions' do
    tree = JCR.parse( '[ ipv4, ipv6, fqdn, idn, email, phone, hex, base32hex, base64url, base64, datetime, date, time ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ ipv4 , ipv6 , fqdn , idn , email , phone , hex , base32hex , base64url , base64 , datetime , date , time ]')
  end

  it 'should print uris' do
    tree = JCR.parse( '[ uri, uri..https, uri..ftp ]')
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ uri , uri..https , uri..ftp ]' )
  end

  it 'should print out an array of arrays with annotations' do
    tree = JCR.parse( '[ @{not}[ integer ], @{root}[ string ] , @{unordered}[ float ] ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ @{not} [ integer ] , @{root} [ string ] , @{unordered} [ float ] ]')
  end

  it 'should print an object with members' do
    tree = JCR.parse( '{ "a":string, "b":integer }' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '{ "a" : string , "b" : integer }')
  end

  it 'should print an group with members' do
    tree = JCR.parse( '( "a":string, "b":integer )' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '( "a" : string , "b" : integer )')
  end

  it 'should print out a rule assignment to an array' do
    tree = JCR.parse( '$t = [ string ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '$t = [ string ]' )
  end

  it 'should print out a rule assignment to member rule' do
    tree = JCR.parse( '$t = "a":string' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '$t = "a" : string' )
  end

  it 'should print out a rule assignment to a primitive rule' do
    tree = JCR.parse( '$t =: "foo"' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '$t =: "foo"' )
  end

  it 'should print repetitions in an array' do
    tree = JCR.parse( '[ integer?, string*, float *1, boolean *1..2, null *0..2, double *1.., string ? ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ integer ? , string * , float *1 , boolean *1..2 , null *0..2 , double *1..INF , string ? ]' )
  end

  it 'should print repetitions with steps in an array' do
    tree = JCR.parse( '[ string*%3, boolean *1..2%3, null *0..2%3, double *1..%3 ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ string *%3 , boolean *1..2%3 , null *0..2%3 , double *1..INF%3 ]' )
  end

  it 'should print out the not annotation on array items' do
    tree = JCR.parse( '[ @{not} string ]' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '[ @{not} string ]' )
  end

  it 'should print out the not annotation on object members in an object rule' do
    tree = JCR.parse( '{ @{not}"a":string }' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '{ @{not} "a" : string }' )
  end

  it 'should print out the not annotation on a member definition in a member rule in an object rule' do
    tree = JCR.parse( '{ "a":@{not}string }' )
    expect( JCR.rule_to_s( tree[0] ) ).to eq( '{ "a" : @{not} string }' )
  end

end
