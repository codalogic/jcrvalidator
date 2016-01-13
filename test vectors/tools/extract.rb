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

# Configuration

puts "Under development"

SPEC_FILE_PATH = '../../spec'
EXTRACTED_PATH = '../extracted'

$is_logging_enabled = false

def main
    interpret_command_line

    scan_all_spec_files
end

def interpret_command_line
    help if ARGV[0] == '-?'
    $is_logging_enabled = true if ARGV[0] == '-l'
end

def help
    puts "extract.rb - Extract JCR test vectors from Ruby Reference Implementation"
    puts "Flags:"
    puts "  -l : Log parsed Ruby test code along with extracted JCR test vectors"
    exit
end

def scan_all_spec_files
    Dir.glob( File.join( SPEC_FILE_PATH, '*.rb' ) ) { |spec_filename|
        extract_test_vectors( spec_filename )
    }
end

def extract_test_vectors( spec_filename )
    test_vector_filename = make_test_vector_filename( spec_filename )
    puts "#{File.basename(spec_filename)} to #{File.basename(test_vector_filename)}"
    File.open( spec_filename ) { |fin|
        File.open( test_vector_filename, 'w' ) { |fout|
            add_license( fout )
            scan_for_test_vectors( fin, fout )
        }
    }
end

def make_test_vector_filename( spec_filename )
    return spec_filename.
                sub( /^#{SPEC_FILE_PATH}/, EXTRACTED_PATH ).
                sub( /\.rb$/, '.jcrtv' )
end

def add_license( fout )
    # Copy license from this file to test vector file
    File.open( __FILE__ ) { |fself|
        while( line = fself.gets )
            break if ! /^#/.match( line )
            fout.write( "#-" + line )
        end
        fout.puts
    }
end

def scan_for_test_vectors( fin, fout )
    while( line = fin.gets )
        if m = /\s*it '(should[^']*)/.match( line )
            Extractor.new( fin, fout, m[1] ).extract
        end
    end
end

class Extractor
    def initialize( fin, fout, description )
        @fin, @fout, @description = fin, fout, description
        @jcr = ''
        @expected_jcr_result = false
        @json = nil
        @expected_json_result = false
    end

    def extract
        scan
        interpret
    end

    private

    def scan
        @fout.puts( "#-# Line: #{@fin.lineno}" ) if $is_logging_enabled
        while( line = @fin.gets )
            break if m = /\s*end/.match( line )

            @fout.write( '#-# ' + line ) if $is_logging_enabled
            if m = /JCR.parse\( '([^']*)'/.match( line )
                @jcr = m[1]
                @expected_jcr_result = true
            end

            if /expect\{/.match( line ) && /JCR/.match( line ) && /}.to raise_error/.match( line )
                @expected_jcr_result = false
            end

            if /JCR.evaluate_rule/.match( line )
                extract_json_from_evaluate_rule( line )
            end

            if /expect\( e.success \).to be_falsey/.match( line )
                @expected_json_result = false
            end
        end
    end

    def extract_json_from_evaluate_rule( line )
        # Example haystack: e = JCR.evaluate_rule( tree[0], tree[0], [ ], JCR::EvalConditions.new( mapping, nil ) )
        json = line
        json.sub!( /.*JCR.evaluate_rule\([^,]+,[^,]+,/, '' )
        json.sub!( /, JCR::Eval.*/, '' )
        @json = json
        @expected_json_result = true
    end

    def interpret
        if @jcr != ''
            @fout.puts "## #{@description}"
            @fout.puts "JCR: #{@expected_jcr_result ? 'Pass' : 'Fail'}"
            @fout.puts "    #{@jcr}"

            if @json
                @fout.puts "JSON: #{@expected_json_result ? 'Pass' : 'Fail'}"
                @fout.puts "    #{@json}"
            end
            @fout.puts
        else
            puts "Unable to extract JCR for:"
            puts "    #{@description}"
            puts "    Line #{@fin.lineno}"
        end
    end
end

main
