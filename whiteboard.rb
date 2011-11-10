#require 'RMagick'
require 'oily_png'
#include Magick

@min_redness = 110
@max_rect_axis_difference = 30

class Blob

	attr_reader :points, :min_x, :min_y, :max_x, :max_y

	@@number_of_blobs = 0

	def initialize
		@points = Array.new

		@min_x = nil
		@min_y = nil

		@max_x = nil
		@max_y = nil
	end

	def add_point(x, y)
		@min_x = x if @min_x.nil? || x < @min_x
		@min_y = y if @min_y.nil? || y < @min_y

		@max_x = x if @max_x.nil? || x > @max_x
		@max_y = y if @max_y.nil? || y > @max_y

		@points << [x, y]
	end

	def center_point
		[(@min_x + @max_x)/2, (@min_y + @max_y)/2]
	end
end

def calc_redness(r, g, b)
	(2 * r) - (g + b)
end

def is_blob_rect?(blob)
	left = blob.min_x
	top = blob.min_y
	right = blob.max_x
	bottom = blob.max_y
	
	width = right - left + 1
	height = bottom - top + 1

	#a square placed on top of the blob
	#check the percentage of pixels that don't 'fill' the square, or go past the square
#	puts "-----------------------------------"
#	puts "top left (" + left.to_s + ", " + top.to_s + ")  -  bottom right: (" + right.to_s + ", " + bottom.to_s + ")"
#	puts "width : " + width.to_s + ", height: " + height.to_s + " width / height = " + (width.to_f / height.to_f).to_s
#	puts "total pixels: " + blob.points.uniq.length.to_s
	coverage = (blob.points.uniq.length.to_f / (width * width).to_f).to_f
	sides_ratio = (width.to_f / height.to_f) 
#	puts "coverage: " + coverage.to_s
#	puts "sides_ratio: " + sides_ratio.to_s
	
#	puts blob.min_x.to_s + " - " + blob.max_x.to_s + ", " + blob.min_y.to_s + " - " + blob.max_y.to_s + ", total px: " + blob.points.uniq.length.to_f.to_s + ", " + "w: " + width.to_s + ", h: " + height.to_s + " : cov: " + coverage.to_s
	
	coverage >= 0.65 && coverage <= 1.35 && sides_ratio >= 0.75 && sides_ratio <= 1.35
end

def in_image_bounds?(image, x, y)
	x > 0 && x < image.dimension.width && y > 0 && y < image.dimension.height
end

def neighbours(image, x, y)
#	[[x-1, y-1], [x, y-1], [x-1, y], [x+1, y-1], [x+1, y+1], [x+1, y], [x, y+1], [x+1, y+1]].select do |n|
	[[x, y-1], [x-1, y], [x+1, y], [x, y+1]].select do |n|
		in_image_bounds?(image, n[0], n[1])		
	end
end

def find_blob(image, blobs, x, y)
	blob = Blob.new
	stack = []
	stack << [x, y]

	while(!stack.empty?)
		next_pixel = stack.pop
		blob.add_point(*next_pixel)

		image[next_pixel[0], next_pixel[1]] = ChunkyPNG::Color.rgb(0, 0, 255)

		neighbours(image, *next_pixel).each do |xy|
			redness = calc_redness(ChunkyPNG::Color.r(image[xy[0], xy[1]]), ChunkyPNG::Color.g(image[xy[0], xy[1]]),
						ChunkyPNG::Color.b(image[xy[0], xy[1]]))
			if redness > @min_redness
				stack << [xy[0], xy[1]]
			end
		end
	end

	blobs << blob if blob.points.uniq.length > 200 && is_blob_rect?(blob)
end

def find_bounding_rect(image, blobs)

	#the first blob I run into scanning left -> right, top -> bottom
	#should be either the top left blob or the top right blob


	blobs.map do |top_blob|

	bottom_blob = nil
	top_side_blob = nil
	bottom_side_blob = nil

		blobs.map do |next_blob|

			if top_blob == next_blob
				next
			end

#			puts "top blob: " + top_blob.center_point.inspect

			#matched a blob below
#			puts "below: comparing: " + top_blob.center_point[0].to_s + " to " + next_blob.center_point.to_s
			if (top_blob.center_point[0] - next_blob.center_point[0]).abs < @max_rect_axis_difference
#				puts "matched bottom: " + top_blob.center_point.to_s + " and " + next_blob.center_point.to_s
				bottom_blob = next_blob
				next
			end

#			puts "side: comparing: " + top_blob.center_point[0].to_s + " to " + next_blob.center_point.to_s
			if (top_blob.center_point[1] - next_blob.center_point[1]).abs < @max_rect_axis_difference
#				puts "top_side matched: " + top_blob.center_point.to_s + " and " + next_blob.center_point.to_s
				top_side_blob = next_blob
				next
			end

#			puts "diagonal: comparing: " + top_blob.center_point[0].to_s + " to " + next_blob.center_point.to_s
			if !top_side_blob.nil? && !bottom_blob.nil?
				
#				puts "top side: " + top_side_blob.center_point.to_s + ", bottom_side: " +  next_blob.center_point.to_s
#				puts "bottom: " + top_side_blob.center_point.to_s + ", bottom_side: " +  next_blob.center_point.to_s
				if (top_side_blob.center_point[0] - next_blob.center_point[0]).abs < @max_rect_axis_difference &&
					(bottom_blob.center_point[1] - next_blob.center_point[1]).abs < @max_rect_axis_difference
					
					bottom_side_blob = next_blob
#					puts "identified rectangle! at: " + top_blob.center_point.to_s + " , " + bottom_side_blob.center_point.to_s

					#return corners of rect for now

					#if we have the top left corner as the top blob
					if top_blob.center_point[0] < bottom_side_blob.center_point[0]
						return  [[top_blob.max_x, top_blob.max_y], [bottom_blob.max_x, bottom_blob.min_y],
								[bottom_side_blob.min_x, bottom_side_blob.min_y], [top_side_blob.min_x, top_side_blob.max_y]]
					else
						#if we have the top right corner as the top blob
						return  [[top_side_blob.max_x, top_side_blob.max_y], [bottom_side_blob.max_x, bottom_side_blob.min_y],
								[bottom_blob.min_x, bottom_blob.min_y], [top_blob.min_x, top_blob.max_y]]
					end

					#	return [top_blob, bottom_blob, top_side_blob, bottom_side_blob]
				end
			end
		end		
	end

	return nil
end

=begin
old_filename = ""
newest_image_command = "ls shots/ -rt | grep .png | tail -1"
filename = %x[#{newest_image_command}].inspect.gsub("\"", "")
filename.gsub!("\\n", "")

while 1
	while filename == old_filename
		if !filename.nil?
			filename = %x[#{newest_image_command}].inspect.gsub("\"", "")
			filename.gsub!("\\n", "")
			puts "current file: " + filename
		end
		
		sleep 1 
	end
=end

#=begin
i = 6
while i <= 81
	filename = "shot" + (sprintf '%04d',i) + ".png"

#=end
#	filename = "shot0032.png"
	puts "loading new file: " + filename
	image = ChunkyPNG::Image.from_file("shots/#{filename}")
	blob_img = image.dup
	width = image.dimension.width

#	img_list = ImageList.new("shots/#{filename}")
#	img_list.rotate!(180)
#	%x[`rm shots/*.png`]
#	blob_view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)
#	orig_img_view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)

	blobs = []
#	width = img_list.bounding_box.width-1
#	height = img_list.bounding_box.height-1

	cur_x = 0
	cur_y = 0

	blob_img.pixels.each do |pixel|
		redness = calc_redness(ChunkyPNG::Color.r(pixel), ChunkyPNG::Color.g(pixel), ChunkyPNG::Color.b(pixel))
		if redness >= @min_redness
			find_blob(blob_img, blobs, cur_x, cur_y)
		end

		cur_x += 1
		if cur_x == width
			cur_y += 1
			cur_x = 0
		end
	end

#	puts "saving blob image"
#	blob_img.save("output/#{filename}_blob.png")

=begin
	blobs.each do |b|
		b.points.each do |point|
			image[point[0], point[1]] = ChunkyPNG::Color.rgb(0, 255, 0)
		end
	end
=end

#	puts "saving image"
#	image.save("output/#{filename}")
	
	boundary = find_bounding_rect(image, blobs)
		
	if !boundary.nil?
		poly_vector = ChunkyPNG::Vector(boundary[0][0], boundary[0][1], boundary[1][0], boundary[1][1],
										boundary[2][0], boundary[2][1], boundary[3][0], boundary[3][1])
		image.polygon(poly_vector, ChunkyPNG::Color.rgb(255, 0, 0))
		image.save("output/#{filename}")
	elsif(blobs.length > 0)
		image.save("output/#{filename}")
	end

	old_filename = filename
	i += 1
end
