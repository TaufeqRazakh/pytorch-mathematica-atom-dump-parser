# Use the Gemfile for dependencies

# Pass the regex of files in quotes as argument 
# ruby batched-atom-plotter.rb "result_set_*_of_five.txt"

require 'humanize'

@sorted_files = 5.times.map {|x| "result_set_"+(x+1).to_i.humanize+"_of_five.txt"}

@steps_per_batch = [4, 5, 8, 6, 6]

@x = 3.7731
@y = 1.5290
@z = 3.6253

@x_s = []
@y_s = []
@z_s = []

def locate_co_ordinates(file_name)
  file_contents = IO.read(file_name)
  found_locations = file_contents.to_enum(:scan, /#{@x.to_s}/).map {Regexp.last_match.begin(0)}
  found_locations
end

def get_offset_from_line_start(file_descriptor)
  offset = 0 
  while file_descriptor.getc != "\n" do
    file_descriptor.seek(-2, IO::SEEK_CUR)
    offset = offset + 1
  end
  offset
end
# open the dump files and read the x,y and z positions for those 
# many steps
def open_file_and_locate_co_ordinates(file_name, steps)
  fd = File.new(file_name)

  found_locations = locate_co_ordinates(file_name)
  p found_locations
  
  fd.seek(found_locations.first - 1)
  left_offset = get_offset_from_line_start(fd)
  p left_offset
  
  
end


# Print the tracked atom positions into an output file for wolfram

# Perform open_file_and_populate for eatch batch

# Start 
open_file_and_locate_co_ordinates(@sorted_files.first, @steps_per_batch.first)  

