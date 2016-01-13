# Copyright (C) 2016 American Registry for Internet Numbers (ARIN)
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

# Checks that the test cases extracted from the Ruby reference code give the
# desired results.

begin
    require 'jcr'
rescue LoadError
    lib = File.expand_path("../../lib",File.dirname(__FILE__))
    $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
    require 'jcr'
end

VETTED_PATH = '../vetted'
EXTRACTED_PATH = '../extracted'

$test_file_path = VETTED_PATH
$specific_test_file = ''

def main
    interpret_command_line

    if $specific_test_file != ''
        verify_single_test_file $specific_test_file
    else
        verify_against_all_test_files
    end
end

def interpret_command_line
    help if ARGV[0] == '-?'
    $test_file_path = EXTRACTED_PATH if ARGV[0] == '-e'
    $test_file_path = ARGV[1] if ARGV[0] == '-d' && ARGV[1]
    $specific_test_file = ARGV[1] if ARGV[0] == '-f' && ARGV[1]
end

def help
    puts "verify.rb - Verify JCR test vectors"
    puts "  Without flags, the program checks against the test files in the"
    puts "  ../vetted directory."
    puts "Flags:"
    puts "  -e : Used 'extracted' test files rather than 'vetted' test files"
    puts "  -d <path> : Use test files located in the directory at <path>"
    puts "  -f <file> : Use test files located in the named test file"
    exit
end

def verify_against_all_test_files
    test_record = TestRecord.new
    Dir.glob( File.join( $test_file_path, '*.jcrtv' ) ) { | filename |
        Verify.new( filename, test_record ).verify
    }
    puts test_record.to_s
end

def verify_single_test_file( test_file )
    test_record = TestRecord.new
    Verify.new( test_file, test_record ).verify
    puts test_record.to_s
end

class TestRecord
    def initialize
        @n_tests = @n_fails = 0
    end

    def record( is_pass )
        @n_tests += 1
        @n_fails += 1 if ! is_pass
        return is_pass
    end

    def num_tests
        return @n_tests
    end

    def num_fails
        return @n_fails
    end

    def to_s
        return "#{@n_fails} fails, #{@n_tests} tests"
    end
end

class Verify
    def initialize( test_filename, test_record )
        @test_filename = test_filename
        @description_tracker = DescriptionTracker.new
        @jcr = ''
        @expected_jcr_result = false
        @json = nil
        @expected_json_result = false
        @test_record = test_record
        @line_num = 0
    end

    class READ_STATE
        SEEKING = 1; READING_JCR = 2; READING_JSON = 3;
    end

    def verify
        puts "#{File.basename( @test_filename )}..."
        LineReader.open( @test_filename ) { |r|
            @reader = r
            @state = READ_STATE::SEEKING
            while( line = gets )
                if ! is_discardable_comment( line )
                    case @state
                    when READ_STATE::SEEKING
                        seeking( line )
                    when READ_STATE::READING_JCR
                        reading_jcr( line )
                    when READ_STATE::READING_JSON
                        reading_json( line )
                    end
                end
            end
            if @state == READ_STATE::READING_JCR || @state == READ_STATE::READING_JSON
                run_test
            end
        }
    end

    private

    def seeking( line )
        if is_description_marker( line )
            @description_tracker.new_description( get_description( line ) )
        elsif is_jcr_marker( line )
            @jcr = ''
            @json = nil
            @expected_jcr_result = is_pass_expected( line )
            @description_tracker.associate_with_jcr
            @line_num = line_num
            @state = READ_STATE::READING_JCR
        elsif is_json_marker( line )
            @json = ''
            @expected_json_result = is_pass_expected( line )
            @description_tracker.associate_with_json
            @line_num = line_num
            @state = READ_STATE::READING_JSON
        end
    end

    def reading_jcr( line )
        if ! is_marker( line )
            @jcr += line
        else
            ungets
            run_test
            @state = READ_STATE::SEEKING
        end
    end

    def reading_json( line )
        if ! is_marker( line )
            @json += line
        else
            ungets
            run_test
            @state = READ_STATE::SEEKING
        end
    end

    def is_discardable_comment( line )
        return /^#-#/.match( line )
    end

    def is_description_marker( line )
        return /^##/.match( line )
    end

    def get_description( line )
        if m = /^##\s*(.+)/.match( line )
            return m[1]
        end
        return ''
    end

    def is_jcr_marker( line )
        return /^JCR:/.match( line )
    end

    def is_json_marker( line )
        return /^JSON:/.match( line )
    end

    def is_marker( line )
        return is_description_marker( line ) ||
                is_jcr_marker( line ) ||
                is_json_marker( line )
    end

    def is_pass_expected( line )
        m = /:\s*(Pass|Fail)/.match( line )
        abort "Abort: Expected 'Pass' or 'Fail' status in file #{@test_filename} line #{line_num}" if ! m
        return m[1] == 'Pass'
    end

    def run_test
        TestRunner.new( @test_record ).run(
                filename: @test_filename, line: @line_num,
                description: @description_tracker.test_description,
                jcr: @jcr, expected_jcr_result: @expected_jcr_result,
                json: @json, expected_json_result: @expected_json_result )
    end

    def gets
        return @reader.gets
    end

    def ungets
        return @reader.ungets
    end

    def line_num
        return @reader.line_num
    end
end

class LineReader
    # Allow going back one line when reading a file a line at a time

    def self.open( filename )
        begin
            lr = LineReader.new( filename )
            yield lr
        ensure
            lr.close
        end
    end

    def initialize( filename )
        @fin = File.open( filename, 'r' )
        @last_line = ''
        @use_last_line = false
        @line_num = 0
    end

    def gets
        if @use_last_line
            @use_last_line = false
            return @last_line
        elsif ! @fin
            return nil
        elsif @fin.eof?
            close
            return nil
        else
            @last_line = @fin.gets
            @line_num += 1
            return @last_line
        end
    end

    def ungets
        @use_last_line = true
    end

    def line_num
        return @line_num
    end

    def close
        @fin.close if @fin
        @fin = nil
    end
end

class DescriptionTracker
    # It's ncessary to make sure that the correct description is associated
    # with the correct test.  This is complicated by the fact that some tests
    # may not have descriptions and it's nice to allow snippets of JSOON to
    # have their own description in addition to a (possible) JCR description.
    # This class keeps track of the latest read description, and then on
    # encountering a JCR or JSON test marker will assign the description
    # accordingly.  A test not having a description is accommodated by
    # an empty @latest_description being copied into the respective slot
    # if a nw description hasn't been assigned since making the previous
    # association.

    def initialize
        @latest_description = ''
        @jcr_description = ''
        @json_description = ''
    end

    def new_description( description )
        @latest_description = description
    end

    def associate_with_jcr
        @jcr_description = @latest_description
        @latest_description = @json_description = ''
    end

    def associate_with_json
        @json_description = @latest_description
        @latest_description = ''
    end

    def test_description
        return @json_description != '' ? @json_description : @jcr_description
    end
end

class TestRunner
    def initialize( test_record )
        @test_record = test_record
    end

    def run( filename:, line:, description:,
            jcr:, expected_jcr_result:,
            json:, expected_json_result: )
        @filename, @line, @description = filename, line, description
        @jcr, @expected_jcr_result = jcr, expected_jcr_result
        @json, @expected_json_result = json, expected_json_result

        if ! @json
            run_jcr_test
        else
            run_json_test
        end
    end

    def run_jcr_test
        is_jcr_ok = true
        begin
            JCR.parse( @jcr )   # Only test syntax of standalone JCR, not all dependencies
        rescue
            is_jcr_ok = false
        end
        if ! @test_record.record( is_jcr_ok == @expected_jcr_result )
            puts "Test failed : #{@description != '' ? @description : ''}"
            puts "    When checking JCR '#{@jcr.strip}'"
            puts "    Expected #{@expected_jcr_result ? 'Pass' : 'Fail'}"
            puts "    File: #{@filename}, line #{@line}"
        end
    end

    def run_json_test
        begin
            jcr_ctx = JCR::Context.new( @jcr )
            json_tree = JSON.parse( @json )
            result = jcr_ctx.evaluate( json_tree )
            if ! @test_record.record( result.success == @expected_json_result )
                puts "Test failed : #{@description != '' ? @description : ''}"
                puts "    When checking '#{@json.strip}' against '#{@jcr.strip}'"
                puts "    Expected #{@expected_json_result ? 'Pass' : 'Fail'}"
                puts "    File: #{@filename}, line #{@line}"
            end
        rescue
            # The JCR should already have been tested standalone, so repeat
            # reporting of a JCR error is not required
        end
    end
end

main
