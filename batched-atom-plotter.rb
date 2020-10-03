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


class String 
  val = ""
  def take_or_pad(length, padstr='')
    # "3488888".take_or_pad(4,'0')
      #=> "3488"
    # "3488888".take_or_pad(0,'0')
      # => "3488888"
    # "3488888".take_or_pad(1,'0')
      #=> "3"      
    if(self.length >= length)
      val = self[0..length-1]
    else
      val = self.ljust(length, padstr)
    end
    val
  end
end

def read_4_decimal_places(input_string)
  val = ""
  split_string = input_string.split('.')
  if (split_string.length > 1)
    val = split_string[0] + "." + split_string[1].take_or_pad(4,'0')
    p val
  else
    val = split_string
  end
  val
end

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

class NoMatchesFound < StandardError
end

class MultipleMatchesFound < StandardError
end
 
def locate_co_ordinate(file_name, length = nil, offset = nil)
  full_file_search   = false
  lower_bound_search = false 
  upper_bound_search = false 
  
  file_contents = IO.read(file_name, length, offset)
  search_co_ordinates = @initial_co_ordinate
  # handle the case of no coherent numbers in trailing files with user input 
  # or search in file again with added tolerance
  begin
    puts "looking for #{search_co_ordinates} in #{file_name}"
    found_locations = file_contents.enum_for(:scan, /#{search_co_ordinates}/).map { Regexp.last_match.begin(0) }
    found_location = found_locations.last
    # An alternative to saech is found_location = (file_contents =~ /#{search_co_ordinates}/)
    # The enum solution is inspired from https://stackoverflow.com/questions/5241653/ruby-regex-match-and-get-positions-of
    
    raise NoMatchesFound if found_locations.empty?
    raise MultipleMatchesFound if found_locations.length > 1 
  rescue NoMatchesFound
    if !lower_bound_search
      puts "NoMatchesFound: attempting lower bound search".magenta
      search_co_ordinates = read_4_decimal_places((@initial_co_ordinate.to_f - 0.0001).to_s)
      lower_bound_search = true
      retry
    elsif !upper_bound_search
      puts "NoMatchesFound: attempting upper bound search".magenta
      search_co_ordinates = read_4_decimal_places((@initial_co_ordinate.to_f + 0.0001).round(4).to_s)
      upper_bound_search = true
      retry
    elsif !full_file_search
      puts "NoMatchesFound: attempting full file search".magenta
      file_contents = IO.read(file_name)
      search_co_ordinates = @initial_co_ordinate
      full_file_search = true
      lower_bound_search = upper_bound_search = false
      length = offset = nil
      retry
    else
      puts "Could not find " + @initial_co_ordinate.inspect.green + " in " + file_name.blue
      print "NoMatchesFound: Type in your input for best possbible atom trajectory begin point: ".magenta
      STDOUT.flush
      search_co_ordinates = gets.chomp
      @initial_co_ordinate = search_co_ordinates
      retry  
    end
  rescue MultipleMatchesFound
    puts "MultipleMatchesFound: make choice of found results to use.".magenta
    some_val = gets.chomp
  end
  
  # Add space to the left if the number has no minus sign.
  # This is done to ensure reading of minus sign in the column if any
  if @initial_co_ordinate.to_s[0] != '-' 
    found_location = found_location - 1
  end
  
  # Correct the found_location if search was done with in file section
  unless offset.nil? 
    found_location += offset
  end
  found_location
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
  
  found_location = locate_co_ordinate(file_name, fileSegmentOfInterest.length, fileSegmentOfInterest.offset)
  puts "found locations for signed "+@initial_co_ordinate.inspect.green+" in "+file_name.blue+" to be #{found_location}"
  
  fd.seek(found_location)
  offset = get_offset_from_line_begin(fd)
  puts "offset distance from line start to arrive at co-ordinate is #{offset}"

  co_ordinates_in_dump = get_traj_co_ordinates_in_dump(fd, offset, steps)
  # after reading n steps the file descripto position marks the end of te interest region 
  fileSegmentOfInterest.set_offset(found_location)
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

def write_co_ords_to_xyz(atom_number, co_ordinates)
  output_file_name = "atom_traj_" + atom_number + ".xyz"
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
    
    co_ordinates_along_dimensions = []
    # read the starting co-ordinate for each dimension
    while (starting_co_ordinate = line_data.shift) do
      @initial_co_ordinate = read_4_decimal_places(starting_co_ordinate)

      co_ordinates_along_dimensions << locate_co_ordinate_along_dimension
    end
    # write co-ordinates to mathematica 
    write_co_ords_as_wolfram_lists_to_file(atom_number, co_ordinates_along_dimensions)
    # write_co_ords_to_xyz(atom_number, co_ordinates_along_dimensions)
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
