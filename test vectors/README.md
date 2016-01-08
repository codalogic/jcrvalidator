# JCR Test Vectors

## tl;dr

If you are looking for test vectors to verify your JCR implementation,
use the files in the `vetted` directory.

## Introduction

This directory contains test material to help third-parties verify their JCR
implementations.  The `extracted` directory contains test files automatically
extracted from the Ruby RSpec files that are used to verify the Ruby reference 
implementation.  These test files are extracted using the scripts in the
`tools` directory.  As the automated transformation of the RSpec code into 
test vectors is not guarenteed to be 100% successful, test files in the 
`extracted` are manually inspected and checked, and those that are correct
(possibly after editting) are placed into the `vetted` directory.  Thus, if you
are just interested in test vectors to test your implementation, use the files
in the `vetted` directory.

## Test File Format

Each test file contains one or more examples of JCR, each of which may have associated 
with it zero or more examples of JSON.  Each JCR example is preceded
by a comment decribing what the JCR and JSON instance are intended to test.  
The test description comment consists of a line that starts with `##` and ends at the
end of the line.  The
JCR for a test is identified by a line that starts with the string `JCR:` and is
followed by either `Pass` or `Fail` depending on whether the JCR is valid or not.
(White space may be included between the `JCR:` and `Pass` / `Fail` tokens.)
The actual JCR for a test begins on the following line and continues until another
test description comment, a `JCR:` declaration or end of file is encountered.  The
optional JSON for a test is identified by a line that starts with the `JSON:` and
is again followed by either `Pass` or `Fail` depending on whether the JSON is valid
according to the previously defined JCR.  The actual JSON starts on the following
line, and, as before, is terminated by another test description comment, a `JCR:`
declaration or an end of file.

For example:

    ## should allow an array of two integers
    JCR: Pass
        [ 2 : integer ]
    JSON: Pass
        [ 1,2 ]
    JSON: Pass
        [ 1000, 2000 ]
    JSON: Fail
        [ 1,2,3 ]
    JSON: Fail
        [ "One", "Two" ]

## The Tools

The `tools` directory contains scripts for creating the test files.  The `extract.rb`
script parses the reference implementation Ruby RSpec files and creates the 
preliminary test files.  `verify.rb` runs the test files against the reference Ruby 
implementation to check that the test files have the correct pass / fail results.

## Status

The test vector creation is Work In Progress.
