# Copyright (c) 2011 Samuel G. D. Williams. <http://www.oriontransfer.co.nz>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'stringio'
require 'find'
require 'digest'

module Fingerprint
	
	# The default pattern for excluding files.
	DEFAULT_EXCLUDES = [/\/\.[^\/]+$/, /\~$/]
	
	# The scanner class can scan a set of directories and produce an index.
	class Scanner
		# Initialize the scanner to scan a given set of directories in order.
		# [+options[:excludes]+]  An array of regular expressions of files to avoid indexing.
		# [+options[:output]+]    An +IO+ where the results will be written.
		def initialize(roots, options = {})
			@roots = roots

			@excludes = options[:excludes] || DEFAULT_EXCLUDES
			@output = options[:output] || StringIO.new
			
			@options = options
		end

		attr :output

		protected
		
		# Adds a header for a given path which is mainly version information.
		def output_header(root)
			@output.puts "\# Checksum generated by Fingerprint (#{Fingerprint::VERSION::STRING}) at #{Time.now.to_s}"
			@output.puts "\# Root: #{root}"
		end
		
		# Output a directory header.
		def output_dir(path)
			@output.puts ""
			@output.puts((" " * 32) + "  #{path}")
		end
		
		# Output a file and associated metadata.
		def output_file(path)
			d = Digest::MD5.new

			File.open(path) do |f|
				while buf = f.read(1024*1024*10)
					d << buf
				end
			end

			@output.puts "#{d.hexdigest}: #{path}"
		end
		
		# Add information about excluded paths.
		def output_excluded(path)
			if @options[:verbose]
				@output.puts '#'.ljust(32) + ": #{path}"
			end
		end

		public
		
		# Returns true if the given path should be excluded.
		def excluded?(path)
			@excludes.each do |exclusion|
				if exclusion.match(path)
					return true
				end
			end

			return false
		end
		
		# Run the scanning process.
		def scan
			excluded_count = 0
			checksummed_count = 0
			directory_count = 0
			
			@roots.each do |root|
				Dir.chdir(root) do
					output_header(root)
					Find.find("./") do |path|
						if File.directory?(path)
							if excluded?(path)
								excluded_count += 1
								output_excluded(path)
								Find.prune # Ignore this directory
							else
								directory_count += 1
								output_dir(path)
							end
						else
							unless excluded?(path)
								checksummed_count += 1
								output_file(path)
							else
								excluded_count += 1
								output_excluded(path)
							end
						end
					end
				end
			end
			
			# Output summary
			@output.puts "\# Directories: #{directory_count} Files: #{checksummed_count} Excluded: #{excluded_count}"
		end

		# A helper function to scan a set of directories.
		def self.scan_paths(paths, options = {})
			scanner = Scanner.new(paths, options)
			
			scanner.scan
			
			return scanner
		end
	end
end
