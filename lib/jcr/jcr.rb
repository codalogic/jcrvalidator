# Copyright (c) 2015-2017 American Registry for Internet Numbers
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

require 'optparse'
require 'rubygems'
require 'json'
require 'pp'

require 'jcr/jcr_validator_error'
require 'jcr/parser'
require 'jcr/evaluate_rules'
require 'jcr/check_groups'
require 'jcr/find_roots'
require 'jcr/map_rule_names'
require 'jcr/process_directives'
require 'jcr/version'
require 'jcr/parts'

module JCR

  class Context
    attr_accessor :mapping, :callbacks, :id, :tree, :roots, :catalog, :trace, :failed_roots, :failure_report
    attr_accessor :failure_report_line_length

    def add_ruleset_alias( ruleset_alias, alias_uri )
      unless @catalog
        @catalog = Hash.new
      end
      @catalog[ ruleset_alias ] = alias_uri
    end

    def remove_ruleset_alias( ruleset_alias )
      if @catalog
        @catalog.delete( ruleset_alias )
      end
    end

    def map_ruleset_alias( ruleset_alias, alias_uri )
      if @catalog
        a = @catalog[ ruleset_alias ]
        if a
          return a
        end
      end
      #else
      return alias_uri
    end

    def evaluate( data, root_name = nil )
      JCR.evaluate_ruleset( data, self, root_name )
    end

    def initialize( ruleset = nil, trace = false )
      @trace = trace
      @failed_roots = []
      if ruleset
        ingested = JCR.ingest_ruleset( ruleset, nil, nil )
        @mapping = ingested.mapping
        @callbacks = ingested.callbacks
        @id = ingested.id
        @tree = ingested.tree
        @roots = ingested.roots
      end
      @failure_report_line_length = 80
    end

    def override( ruleset )
      overridden = JCR.ingest_ruleset( ruleset, @mapping, nil )
      mapping = {}
      mapping.merge!( @mapping )
      mapping.merge!( overridden.mapping )
      overridden.mapping=mapping
      callbacks = {}
      callbacks.merge!( @callbacks )
      callbacks.merge!( overridden.callbacks )
      overridden.callbacks = callbacks
      overridden.roots.concat( @roots )
      return overridden
    end

    def override!( ruleset )
      overridden = JCR.ingest_ruleset( ruleset, @mapping, nil )
      @mapping.merge!( overridden.mapping )
      @callbacks.merge!( overridden.callbacks )
      @roots.concat( overridden.roots )
    end

  end

  def self.ingest_ruleset( ruleset, existing_mapping = nil, ruleset_alias=nil )
    tree = JCR.parse( ruleset )
    mapping = JCR.map_rule_names( tree, ruleset_alias )
    combined_mapping = {}
    combined_mapping.merge!( existing_mapping ) if existing_mapping
    combined_mapping.merge!( mapping )
    JCR.check_rule_target_names( tree, combined_mapping )
    JCR.check_groups( tree, combined_mapping )
    roots = JCR.find_roots( tree )
    ctx = Context.new
    ctx.tree = tree
    ctx.mapping = mapping
    ctx.callbacks = {}
    ctx.roots = roots
    JCR.process_directives( ctx )
    return ctx
  end

  def self.evaluate_ruleset( data, ctx, root_name = nil )
    roots = []
    if root_name
      root_rule = ctx.mapping[root_name]
      raise JcrValidatorError, "No rule by the name of #{root_name} for a root rule has been found" unless root_rule
      root = JCR::Root.new( root_rule, root_name )
      roots << root
    else
      roots = ctx.roots
    end

    raise JcrValidatorError, "No root rule defined. Specify a root rule name" if roots.empty?

    retval = nil
    roots.each do |r|
      pp "Evaluating Root:", rule_to_s( r.rule, false ) if ctx.trace
      raise JcrValidatorError, "Root rules cannot be member rules" if r.rule[:member_rule]
      econs = EvalConditions.new( ctx.mapping, ctx.callbacks, ctx.trace )
      retval = JCR.evaluate_rule( r.rule, r.rule, data, econs )
      break if retval.success
      # else
      r.failures = econs.failures
      ctx.failed_roots << r
    end

    ctx.failure_report = failure_report( ctx )
    return retval
  end

  def self.failure_report ctx
    report = []
    ctx.failed_roots.each do |failed_root|
      if failed_root.name
        report << "- Failures for root rule named '#{failed_root.name}'"
      else
        report << "- Failures for root rule at line #{failed_root.pos[0]}"
      end
      failed_root.failures.each_with_index do |failures,stack_level|
        if failures.length > 1
          report << "  - failure at rule level #{stack_level} caused by one of the following #{failures.length} reasons"
        else
          report << "  - failure at rule level #{stack_level} caused by"
        end
        failures.each_with_index do |failure, index|
          lines = breakup_message( "<< #{failure.json_elided} >> failed rule #{failure.definition}", ctx.failure_report_line_length - 5 )
          lines.each_with_index do |l,i|
            if i == 0
              report << "    - #{l}"
            else
              report << "      #{l}"
            end
          end
        end
      end
    end
    return report
  end

  def self.breakup_message( message, line_length )
    line = message.gsub(/(.{1,#{line_length}})(\s+|\Z)/, "\\1\n")
    lines = []
    line.each_line do |l|
      lines << l.strip
    end
    return lines
  end

  def self.main my_argv=nil

    my_argv = ARGV unless my_argv

    options = {}

    opt_parser = OptionParser.new do |opt|
      opt.banner = "Usage: jcr [OPTIONS] [JSON_FILES]"
      opt.separator  ""
      opt.separator  "Evaluates JSON against JSON Content Rules (JCR)."
      opt.separator  ""
      opt.separator  "If -J is not specified, JSON_FILES is used."
      opt.separator  "If JSON_FILES is not specified, standard input (STDIN) is used."
      opt.separator  ""
      opt.separator  "Use -v to see results, otherwise check the exit code."
      opt.separator  ""
      opt.separator  "Options"

      opt.on("-r FILE","file containing ruleset") do |ruleset|
        if options[:ruleset]
          puts "A ruleset has already been specified. Use -h for help.", ""
          return 2
        end
        options[:ruleset] = File.open( ruleset ).read
      end

      opt.on("-R STRING","string containing ruleset. Should probably be quoted") do |ruleset|
        if options[:ruleset]
          puts "A ruleset has already been specified. Use -h for help.", ""
          return 2
        end
        options[:ruleset] = ruleset
      end

      opt.on("--test-jcr", "parse and test the JCR only") do |testjcr|
        options[:testjcr] = true
      end

      opt.on("--process-parts [DIRECTORY]", "creates smaller files for specification writing" ) do |directory|
        options[:process_parts] = true
        options[:process_parts_directory] = directory
      end

      opt.on("-S STRING","name of root rule. All roots will be tried if none is specified") do |root_name|
        if options[:root_name]
          puts "A root has already been specified. Use -h for help.", ""
          return 2
        end
        options[:root_name] = root_name
      end

      opt.on("-o FILE","file containing overide ruleset (option can be repeated)") do |ruleset|
        unless options[:overrides]
          options[:overrides] = Array.new
        end
        options[:overrides] << File.open( ruleset ).read
      end

      opt.on("-O STRING","string containing overide rule (option can be repeated)") do |rule|
        unless options[:overrides]
          options[:overrides] = Array.new
        end
        options[:overrides] << rule
      end

      opt.on("-J STRING","string containing JSON to evaluate. Should probably be quoted") do |json|
        if options[:json]
          puts "JSON has already been specified. Use -h for help.", ""
          return 2
        end
        options[:json] = json
      end

      opt.on("-v","verbose") do |verbose|
        options[:verbose] = true
      end

      opt.on("-q","quiet") do |quiet|
        options[:quiet] = true
      end

      opt.on("-h","display help") do |help|
        options[:help] = true
      end

      opt.separator  ""
      opt.separator  "Return codes:"
      opt.separator  " 0 = success"
      opt.separator  " 1 = bad JCR parsing or other bad condition"
      opt.separator  " 2 = invalid option or bad use of command"
      opt.separator  " 3 = unsuccessful evaluation of JSON"

      opt.separator  ""
      opt.separator  "JCR Version " + JCR::VERSION
    end

    begin
      opt_parser.parse! my_argv
    rescue OptionParser::InvalidOption => e
      puts "Unable to interpret command or options"
      puts e.message
      puts "", "Use -h for help"
      return 2
    end

    if options[:help]
      puts "HELP","----",""
      puts opt_parser
      return 2
    elsif !options[:ruleset]
      puts "No ruleset passed! Use -R or -r options.", ""
      puts "Use -h for help"
      return 2
    else

      begin

        ctx = Context.new( options[:ruleset], options[:verbose] )
        if options[:overrides]
          options[:overrides].each do |ov|
            ctx.override!( ov )
          end
        end

        if options[:verbose]
          pp "Ruleset Parse Tree", ctx.tree
          puts "Ruleset Map"
          ctx.mapping.each do |name,rule|
            puts "Parsed Rule: #{name}"
            puts rule_to_s( rule, false )
            puts "Parsed Rule Structure: #{name}"
            pp rule
          end
        end

        if options[:process_parts]
          parts = JCR::JcrParts.new
          parts.process_ruleset( options[:ruleset], options[:process_parts_directory] )
          if options[:overrides ]
            options[:overrides].each do |ov|
              parts = JCR::JcrParts.new
              parts.process_ruleset( ov, options[:process_parts_directory] )
            end
          end
        end

        if options[:testjcr]
          #we got this far which means the JCR was already parsed without
          #issue. therefore return 0
          return 0
        elsif options[:json]
          data = JSON.parse( options[:json] )
          ec = cli_eval( ctx, data, options[:root_name], options[:quiet] )
          return ec
        elsif $stdin.tty?
          ec = 0
          if my_argv.empty?
            ec = 2
          else
            my_argv.each do |fn|
              data = JSON.parse( File.open( fn ).read )
              tec = cli_eval( ctx, data, options[:root_name], options[:quiet] )
              ec = tec if tec != 0 #record error but don't let non-error overwrite error
            end
          end
          return ec
        else
          lines = ""
          ec = 0
          ARGF.each do |line|
            lines = lines + line
            if ARGF.eof?
              data = JSON.parse( lines )
              tec = cli_eval( ctx, data, options[:root_name], options[:quiet] )
              ec = tec if tec != 0 #record error but don't let non-error overwrite error
              lines = ""
            end
          end
          return ec
        end

      rescue JCR::JcrValidatorError => jcr_error
        puts jcr_error.message
        return 1
      rescue Parslet::ParseFailed => failure
        puts failure.parse_failure_cause.ascii_tree unless options[:quiet]
        return 1
      rescue JSON::ParserError => parser_error
        unless options[:quiet]
          puts "Unable to parse JSON"
          puts parser_error.message.inspect
        end
        return 3
      end

    end

  end

  def self.cli_eval ctx, data, root_name, quiet
    ec = 2
    e = ctx.evaluate( data, root_name )
    if e.success
      unless quiet
        puts "Success!"
      end
      ec = 0
    else
      unless quiet
        puts "Failure! Use -v for more information."
        ctx.failure_report.each do |line|
          puts line
        end
      end
      ec = 3
    end
    return ec
  end

end