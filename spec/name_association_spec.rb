# Copyright (C) 2015-2016 American Registry for Internet Numbers (ARIN)
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
require_relative '../lib/jcr/name_association'

describe 'name_association' do

  it 'should give a key of "lmn" for literal member name "mn"' do
    tree = JCR.parse( '$rrule = "mn" :integer' )
    expect( JCR::NameAssociation.key( tree[0][:rule][:member_rule] ) ).to eq( "lmn" )
    expect( tree[0][:rule][:member_rule][:member_name_key] ).to eq( "lmn" )
  end

  it 'should give a key of "r/mn" for regex member name /mn/' do
    tree = JCR.parse( '$rrule = /mn/ :integer' )
    expect( JCR::NameAssociation.key( tree[0][:rule][:member_rule] ) ).to eq( "r/mn" )
    expect( tree[0][:rule][:member_rule][:member_name_key] ).to eq( "r/mn" )
  end

  it 'should give a key of "rix/mn" for regex member name /mn/ix' do
    tree = JCR.parse( '$rrule = /mn/ix :integer' )
    expect( JCR::NameAssociation.key( tree[0][:rule][:member_rule] ) ).to eq( "rix/mn" )
    expect( tree[0][:rule][:member_rule][:member_name_key] ).to eq( "rix/mn" )
  end

  it 'should give a key of "w" for wildcard member name //' do
    tree = JCR.parse( '$rrule = // :integer' )
    expect( JCR::NameAssociation.key( tree[0][:rule][:member_rule] ) ).to eq( "w" )
    expect( tree[0][:rule][:member_rule][:member_name_key] ).to eq( "w" )
  end

  it 'should give key of "lmn" jcr member names "mn", /mn/, //' do
    tree = JCR.parse( '$rrule = "mn" :integer $r2 = /mn/ : string $r3 = // : string' )
    na = JCR::NameAssociation.new
    na.add_rule_name tree[0][:rule][:member_rule]
    na.add_rule_name tree[1][:rule][:member_rule]
    na.add_rule_name tree[2][:rule][:member_rule]
    expect( na.key_from_json( "mn" ) ).to eq( "lmn" )
  end

  it 'should give key of "lmn" jcr member names //, "mn", /mn/' do
    tree = JCR.parse( '$r3 = // : string $rrule = "mn" :integer $r2 = /mn/ : string' )
    na = JCR::NameAssociation.new
    na.add_rule_name tree[0][:rule][:member_rule]
    na.add_rule_name tree[1][:rule][:member_rule]
    na.add_rule_name tree[2][:rule][:member_rule]
    expect( na.key_from_json( "mn" ) ).to eq( "lmn" )
  end

  it 'should give key of "lmn" jcr member names /mn/, "mn", //' do
    tree = JCR.parse( '$r2 = /mn/ : string $rrule = "mn" :integer $r3 = // : string' )
    na = JCR::NameAssociation.new
    na.add_rule_name tree[0][:rule][:member_rule]
    na.add_rule_name tree[1][:rule][:member_rule]
    na.add_rule_name tree[2][:rule][:member_rule]
    expect( na.key_from_json( "mn" ) ).to eq( "lmn" )
  end

  it 'should give key of "r/mn" jcr member names /mn/, //' do
    tree = JCR.parse( '$r2 = /mn/ : string $r3 = // : string' )
    na = JCR::NameAssociation.new
    na.add_rule_name tree[0][:rule][:member_rule]
    na.add_rule_name tree[1][:rule][:member_rule]
    expect( na.key_from_json( "mn" ) ).to eq( "r/mn" )
  end

  it 'should give key of "r/mn" jcr member names //, /mn/' do
    tree = JCR.parse( '$r3 = // : string $r2 = /mn/ : string' )
    na = JCR::NameAssociation.new
    na.add_rule_name tree[0][:rule][:member_rule]
    na.add_rule_name tree[1][:rule][:member_rule]
    expect( na.key_from_json( "mn" ) ).to eq( "r/mn" )
  end

  it 'should give key of "r/mn" with json name "mno" with jcr member names "mn", /mn/, //' do
    tree = JCR.parse( '$rrule = "mn" :integer $r2 = /mn/ : string $r3 = // : string' )
    na = JCR::NameAssociation.new
    na.add_rule_name tree[0][:rule][:member_rule]
    na.add_rule_name tree[1][:rule][:member_rule]
    na.add_rule_name tree[2][:rule][:member_rule]
    expect( na.key_from_json( "mno" ) ).to eq( "r/mn" )
  end

  it 'should give key of "w" with json name "xyz" with jcr member names "mn", /mn/, //' do
    tree = JCR.parse( '$rrule = "mn" :integer $r2 = /mn/ : string $r3 = // : string' )
    na = JCR::NameAssociation.new
    na.add_rule_name tree[0][:rule][:member_rule]
    na.add_rule_name tree[1][:rule][:member_rule]
    na.add_rule_name tree[2][:rule][:member_rule]
    expect( na.key_from_json( "xyz" ) ).to eq( "w" )
  end

  it 'should give key of "" with json name "xyz" with jcr member names "mn", /mn/' do
    tree = JCR.parse( '$rrule = "mn" :integer $r2 = /mn/ : string' )
    na = JCR::NameAssociation.new
    na.add_rule_name tree[0][:rule][:member_rule]
    na.add_rule_name tree[1][:rule][:member_rule]
    expect( na.key_from_json( "xyz" ) ).to eq( "" )
  end

end
