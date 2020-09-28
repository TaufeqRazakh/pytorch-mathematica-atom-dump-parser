# Use the Gemfile for dependencies

# Pass the regex of files in quotes as argument
# ruby batched-atom-plotter.rb "result_set_*_of_five.txt"
# Finally generate plots with this script
# (1..32).each {|i| puts "Graphics3D[{Blue, Thick, Line[mdtraj#{i}]}],"}

require 'humanize'
require 'rainbow/refinement'
require 'pry'

using Rainbow

@sorted_files = 5.times.map {|x| "result_set_"+(x+1).to_i.humanize+"_of_five.txt"}

@steps_per_batch = [4, 5, 8, 6, 6]

@sorted_files_and_steps = @sorted_files.zip(@steps_per_batch)

@initial_co_ordinate = 0

class FileSegmentOfInterest
  attr_accessor :length, :offset, :integer_offset
  
  # line_offset, file_offset
  def initialize
    @length = nil
    @offset = nil
    @integer_offset = 0
  end
  
  def set_offset(offset)
    @offset = offset
    @integer_offset = offset
    @length = 70
  end
  
  def set_read_lenght_until(mark)
    @length = mark - @offset
  end
  
end
 
def locate_co_ordinates(file_name, length = nil, offset = nil)
  full_file_search   = false
  lower_bound_search = false 
  upper_bound_search = false 
  
  file_contents = IO.read(file_name, length, offset)
  search_co_ordinates = @initial_co_ordinate
  # handle the case of no coherent numbers in trailing files with user input 
  # or search in file again with added tolerance
  begin
    found_locations = line.enum_for(:scan, /#{search[0, search.length - 1]}\d/).map 
     Regexp.last_match(0) }
    # found_location = file_contents =~ /#{search_co_ordinates}/
    raise if found_location == nil 
  rescue 
    unless lower_bound_search
      search_co_ordinates = (@initial_co_ordinate.to_f - 0.0001).to_s
      lower_bound_search = true
      retry
    end
    unless upper_bound_search
      search_co_ordinates = (@initial_co_ordinate.to_f + 0.0001).to_s
      upper_bound_search = true
      retry
    end
    unless full_file_search
      puts "attempting full file search"
      file_contents = IO.read(file_name)
      search_co_ordinates = @initial_co_ordinate
      full_file_search = true
      lower_bound_search = upper_bound_search = false
      length = offset = nil
      retry
    end
    puts "Could not find " + @initial_co_ordinate.inspect.green + " in " + file_name.blue
    print "Type in your input for best possbible atom trajectory begin point: "
    STDOUT.flush
    search_co_ordinates = gets.chomp
    @initial_co_ordinate = search_co_ordinates
    retry
  end
  if @initial_co_ordinate.to_s[0] != '-' 
    found_location = found_location - 1
  end
  # I found_locations is not of size 2 re do search in remaining segment with +/–0.0001 tolerance
  unless offset.nil? 
    found_location += offset
  end
  [found_location]
end

def get_offset_from_line_begin(file_descriptor)
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
    co_ordinate = file_descriptor.read(6)
    co_ords.append(co_ordinate)
    file_descriptor.gets
  }
  co_ords
end

def open_dump_and_locate_co_ordinate(file_name, steps, fileSegmentOfInterest)
  fd = File.new(file_name)
  
  found_locations = locate_co_ordinates(file_name, fileSegmentOfInterest.length, fileSegmentOfInterest.offset)
  puts "found locations for signed "+@initial_co_ordinate.inspect.green+" in "+file_name.blue+" to be #{found_locations}"
  
  fd.seek(found_locations.first)
  offset = get_offset_from_line_begin(fd)
  puts "offset distance from line start to arrive at co-ordinate is #{offset}"

  co_ordinates_in_dump = get_traj_co_ordinates_in_dump(fd, offset, steps)
  # after reading n steps the file descripto position marks the end of te interest region 
  fileSegmentOfInterest.set_offset(found_locations.first)
  fileSegmentOfInterest.set_read_lenght_until(fd.pos)
  @initial_co_ordinate = co_ordinates_in_dump.last.strip
  co_ordinates_in_dump
end

def locate_co_ordinate_along_dimension
  co_ordinates_along_dimension = []
  fileSegmentOfInterest = FileSegmentOfInterest.new()
  puts "\u{1F600} initiaing trajectory grab starting from #{@initial_co_ordinate}"
  @sorted_files_and_steps.each do |file_name, steps|
    co_ordinates_from_dump = open_dump_and_locate_co_ordinate(file_name, steps, fileSegmentOfInterest)
    co_ordinates_from_dump.each { |v| co_ordinates_along_dimension.append(v) }
    puts "co-ordinates \u{1F373} for atom in this dimension so far are :\n#{co_ordinates_along_dimension}"
  end
  co_ordinates_along_dimension
end

def write_co_ords_to_file(file_name, co_ordinates)
  fd = File.open(file_name, "w+")

  dimensions = {}
  co_ordinates.each_index { |i| dimensions[:"#{i+1}"] = co_ordinates[i] }

  co_ordinates.first.each_index do |step|
    spatial_location = []
    dimensions.keys.each { |key| spatial_location << dimensions[key][step] }
    mathematica_list = "{%{entry}}," % {:entry => spatial_location.join(', ')}
    fd.puts(mathematica_list)
  end
  fd.flush
end

def write_co_ords_as_wolfram_lists_to_file(atom_number, co_ordinates)
  fd = File.open("mathematica_dump.txt", "a+")
  
  dimensions = {}
  co_ordinates.each_index { |i| dimensions[:"#{i+1}"] = co_ordinates[i] }
  
  list_statement = "mdtraj"+atom_number+"=List["
  fd.puts(list_statement)
  
  trajectory = []
  
  co_ordinates.first.each_index do |step|
    spatial_location = []
    dimensions.keys.each { |key| spatial_location << dimensions[key][step] }
    mathematica_list = "{%{entry}}" % {:entry => spatial_location.join(', ')}
    trajectory << mathematica_list
  end
  fd.puts(trajectory.join(', '))
  fd.puts("]")
  
  fd.flush
end
  
def read_start_points_from_xyz(file_name)
  fd = File.new(file_name)

  # .xyz file has first line with number of atoms
  number_of_atoms = fd.readline.to_i

  # .xyz has second line empty
  fd.readline
  
  File.open("mathematica_dump.txt", "w")
  
  # read co-ordinates in file in each lines
  fd.each do |line|
    # divide line into data
    line_data = line.split
    atom_number = line_data.shift
    output_file_name = "atom_traj_" + atom_number + ".txt"
    
    co_ordinates_along_dimensions = []
    # read the starting co-ordinate for each dimension
    while (starting_co_ordinate = line_data.shift) do
      @initial_co_ordinate = starting_co_ordinate[0,7].to_f.round(4).to_s

      co_ordinates_along_dimensions << locate_co_ordinate_along_dimension
    end
    # write co-ordinates to mathematica 
    write_co_ords_as_wolfram_lists_to_file(atom_number, co_ordinates_along_dimensions)
    # write_co_ords_to_file(output_file_name, co_ordinates_along_dimensions)
    # co_ordinates_along_dimensions
  end
end

# Start
# open_dump_and_locate_co_ordinates(@sorted_files.first, @steps_per_batch.first)
unless (ARGV.empty?)
  project = ARGV.shift
  Dir.chdir(Dir[project].to_enum.filter { |i| Dir.exists?(i) }.first)
end

read_start_points_from_xyz('frame130.xyz')
puts "check output files"
