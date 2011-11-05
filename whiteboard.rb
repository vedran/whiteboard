require 'RMagick'
include Magick

class Blob

	attr_reader :points, :min_x, :min_y, :max_x, :max_y, :avg_x, :avg_y

	@@number_of_blobs = 0

	def initialize
		@points = Array.new

		@avg_x = 0
		@avg_y = 0

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
		@avg_x = ((@avg_x * (@points.length-1)) + x) / (@points.length)
		@avg_y = ((@avg_y * (@points.length-1)) + y) / (@points.length)
	end

	def center_point
		[(@min_x + @max_x)/2, (@min_y + @max_y)/2]
	end
end

def quantumify(number)
	(number.to_f / 255.0) * Magick::QuantumRange
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
#	puts blob.avg_x.to_s + ", " + blob.avg_y.to_s
#	puts "-----------------------------------"
#	puts "top left (" + left.to_s + ", " + top.to_s + ")  -  bottom right: (" + right.to_s + ", " + bottom.to_s + ")"
#	puts "width : " + width.to_s + ", height: " + height.to_s + " width / height = " + (width.to_f / height.to_f).to_s
#	puts "total pixels: " + blob.points.uniq.length.to_s
	coverage = (blob.points.uniq.length.to_f / (width * width).to_f).to_f
	sides_ratio = (width.to_f / height.to_f) 
#	puts "coverage: " + coverage.to_s
#	puts blob.min_x.to_s + " - " + blob.max_x.to_s + ", " + blob.min_y.to_s + " - " + blob.max_y.to_s + ", total px: " + blob.points.uniq.length.to_f.to_s + ", " + "w: " + width.to_s + ", h: " + height.to_s + " : cov: " + coverage.to_s
	
	coverage >= 0.65 && coverage <= 1.35 && sides_ratio >= 0.75 && sides_ratio <= 1.25
end

def in_image_bounds?(image, x, y)
	x > 0 && x < image.columns && y > 0 && y < image.rows
end

def neighbours(image, x, y)
#	[[x-1, y-1], [x, y-1], [x-1, y], [x+1, y-1], [x+1, y+1], [x+1, y], [x, y+1], [x+1, y+1]].select do |n|
	[[x, y-1], [x-1, y], [x+1, y], [x, y+1]].select do |n|
		in_image_bounds?(image, n[0], n[1])		
	end
end

def find_blob(view, image, blobs, x, y)
	blob = Blob.new
	stack = []
	stack << [x, y]

	while(!stack.empty?)
		next_pixel = stack.pop
		blob.add_point(*next_pixel)

		view[next_pixel[1]][next_pixel[0]] = Pixel.new(quantumify(254), quantumify(254), quantumify(254))
#		view[next_pixel[1]][next_pixel[0]].blue = quantumify(255)

		neighbours(image, *next_pixel).each do |xy|
			if view[xy[1]][xy[0]].red == quantumify(255)
				stack << [xy[0], xy[1]]
			end
		end
	end

	blobs << blob if blob.points.uniq.length > 150 && is_blob_rect?(blob)
end

def find_bounding_rect(view, image, blobs)

	#the first blob I run into scanning left -> right, top -> bottom
	#should be either the top left blob or the top right blob

	max_difference_value = 20

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
			if (top_blob.center_point[0] - next_blob.center_point[0]).abs < max_difference_value
#				puts "matched bottom: " + top_blob.center_point.to_s + " and " + next_blob.center_point.to_s
				bottom_blob = next_blob
				next
			end

#			puts "side: comparing: " + top_blob.center_point[0].to_s + " to " + next_blob.center_point.to_s
			if (top_blob.center_point[1] - next_blob.center_point[1]).abs < max_difference_value
#				puts "top_side matched: " + top_blob.center_point.to_s + " and " + next_blob.center_point.to_s
				top_side_blob = next_blob
				next
			end

#			puts "diagonal: comparing: " + top_blob.center_point[0].to_s + " to " + next_blob.center_point.to_s
			if !top_side_blob.nil? && !bottom_blob.nil?
				
#				puts "top side: " + top_side_blob.center_point.to_s + ", bottom_side: " +  next_blob.center_point.to_s
#				puts "bottom: " + top_side_blob.center_point.to_s + ", bottom_side: " +  next_blob.center_point.to_s
				if (top_side_blob.center_point[0] - next_blob.center_point[0]).abs < max_difference_value &&
					(bottom_blob.center_point[1] - next_blob.center_point[1]).abs < max_difference_value
					
					bottom_side_blob = next_blob
#					puts "identified rectangle! at: " + top_blob.center_point.to_s + " , " + bottom_side_blob.center_point.to_s

					#return corners of rect for now

					#if we have the top left corner as the top blob
					if top_blob.center_point[0] < bottom_side_blob.center_point[0]
						return  [[top_blob.max_x, top_blob.max_y], [bottom_side_blob.min_x, bottom_side_blob.min_y]]
					else
						#if we have the top right corner as the top blob
						return 	[[top_blob.min_x, top_blob.max_y], [bottom_side_blob.max_x, bottom_side_blob.min_y]]
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
i = 3
while i < 9
	filename = "shot" + (sprintf '%04d',i) + ".png"

#=end
#	filename = "shot0032.png"
	puts "loading new file: " + filename
	img_list = ImageList.new("shots/#{filename}")
	img_list.rotate!(180)
#	%x[`rm shots/*.png`]
	blob_view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)
	orig_img_view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)

	blobs = []
	width = img_list.bounding_box.width-1
	height = img_list.bounding_box.height-1

	blob_view[][].each do |pixel|
		if (2 * pixel.red) - (pixel.green + pixel.blue) > quantumify(125)
#			pixel = Pixel.new(quantumify(255), 0, 0)
			pixel.red  = quantumify(255)
			pixel.blue = pixel.green = 0
		else
			pixel.red = pixel.green = pixel.blue = 0
		end
	end


#	img_list.write("output/#{filename}_orig.png")
#	blob_view.sync
#	img_list.write("output/#{filename}_blobs.png")

	for cur_y in (0..height) do
		for cur_x in (0..width) do
			if blob_view[cur_y][cur_x].red == quantumify(255)
				find_blob(blob_view, img_list, blobs, cur_x, cur_y)
			end
		end
	end


#blob debug code
	blobs.each do |b|
		b.points.each do |p|	
			orig_img_view[p[1]][p[0]] = Pixel.new(quantumify(255), quantumify(255), quantumify(255))
		end
	end

#	orig_img_view.sync
#	img_list.write("output/#{filename}")

	boundary = find_bounding_rect(orig_img_view, img_list, blobs)
		
	if !boundary.nil?
#		painter = Magick::Draw.new
#		painter.stroke('green')
#		painter.stroke_width(3)
#		puts boundary.inspect
#		painter.rectangle(boundary[0][0], boundary[0][1], boundary[1][0], boundary[1][1])
#		painter.draw(img_list)img_list
		width = boundary[1][0] - boundary[0][0];
		height = boundary[1][1] - boundary[0][1];
#		puts "x : " + boundary[0][0].to_s + ", y : " + boundary[0][1].to_s + ", width: " + width.to_s + " , height: " + height.to_s
		puts "cropping..."
		img_list.crop!(boundary[0][0], boundary[0][1], width, height)
		img_list.write("output/#{filename}")
	end

#	if(blobs.length > 0)
#		img_list.write("output/#{filename}")
#	end

	old_filename = filename
	i += 1
end
