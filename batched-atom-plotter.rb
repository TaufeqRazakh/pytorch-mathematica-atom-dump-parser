# Use the Gemfile for dependencies

# Pass the regex of files in quotes as argument 
# ruby batched-atom-plotter.rb "result_set_*_of_five.txt"

require 'humanize'
require 'rainbow/refinement'

using Rainbow

@sorted_files = 5.times.map {|x| "result_set_"+(x+1).to_i.humanize+"_of_five.txt"}

@steps_per_batch = [4, 5, 8, 6, 6]

@sorted_files_and_steps = @sorted_files.zip(@steps_per_batch)

@output_file_name = ""

@x = 0
@y = 1.5290
@z = 3.6253

@x_s = []
@y_s = []
@z_s = []

def locate_co_ordinates(file_name)
  file_contents = IO.read(file_name)
  found_locations = file_contents.to_enum(:scan, /#{@x.to_s}/).map {Regexp.last_match.begin(0)}
  # I found_locations is not of size 2 re do search in remaining segment with +/–0.0001 tolerance
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

def get_traj_co_ordinates_in_dump(file_descriptor, offset, steps)
  co_ords = []
  steps.times {
    file_descriptor.seek(offset, IO::SEEK_CUR)
    # probably read until you get a space
    co_ordinate = file_descriptor.read(@x.to_s.length)
    co_ords.append(co_ordinate)
    file_descriptor.gets
  }
  co_ords
end

# open the dump files and read the x,y and z positions for those 
# many steps
def open_dump_and_locate_co_ordinate(file_name, steps)
  fd = File.new(file_name)

  found_locations = locate_co_ordinates(file_name)
  puts "found locations for "+@x.inspect.green+" in "+file_name.blue+" to be #{found_locations}"
  
  fd.seek(found_locations.first - 1)
  offset = get_offset_from_line_start(fd)
  puts "offset distance from line start to arrive at co-ordinate is #{offset}"
  
  co_ordinates_in_dump = get_traj_co_ordinates_in_dump(fd, offset, steps)
  @x_s = @x_s.union(co_ordinates_in_dump)
  @x = @x_s.last
  puts "co-ordinates \u{1F373} for atom in this dimension so far are :\n#{@x_s}"
  
end

def read_start_points_from_xyz(file_name)
  fd = File.new(file_name)
  
  # .xyz file has first line with number of atoms
  number_of_atoms = fd.readline.to_i
  
  # .xyz has second line empty
  fd.readline
  
  # .read starting co-ordinated from lines
  line = fd.readline
  
  # divide line into data
  line_data = line.split
  output_file_name = "atom_traj_" + line_data.shift
  
  # read the starting co-ordinate for each dimension
  while (starting_co_ordinate = line_data.shift) do 
    @x = starting_co_ordinate.to_f.round(4)
    puts "\u{1F600} initiaing trajectory grab starting from #{@x}"
    @x_s = []
    @sorted_files_and_steps.each do |file_name, steps|
      open_dump_and_locate_co_ordinate(file_name, steps)
    end
  end
  
end

# Print the tracked atom positions into an output file for wolfram

# Perform open_file_and_populate for eatch batch

# Start 
# open_dump_and_locate_co_ordinates(@sorted_files.first, @steps_per_batch.first)
read_start_points_from_xyz('frame130.xyz')
