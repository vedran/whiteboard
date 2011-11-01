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

end

def quantumify(number)
	(number.to_f / 255.0) * Magick::QuantumRange
end

def is_blob_rect?(blob)
	left = blob.min_x
	right = blob.max_x
	top = blob.min_y
	bottom = blob.max_y
	
	width = right - left
	height = bottom - top

	#a square placed on top of the blob
	#check the percentage of pixels that don't 'fill' the square, or go past the square
#	puts blob.avg_x.to_s + ", " + blob.avg_y.to_s
	coverage = (blob.points.uniq.length.to_f / (width * height).to_f).to_f
	puts blob.min_x.to_s + " - " + blob.max_x.to_s + ", " + blob.min_y.to_s + " - " + blob.max_y.to_s + ", " + blob.points.length.to_f.to_s + ", " + "w: " + width.to_s + ", h: " + height.to_s + " : cov: " + coverage.to_s
	coverage >= 0.80 && coverage <= 1.3
end

def in_image_bounds?(image, x, y)
	x > 0 && x < image.columns && y > 0 && y < image.rows
end

def neighbours(image, x, y)
	[[x-1, y-1], [x, y-1], [x-1, y], [x+1, y-1], [x+1, y+1], [x+1, y], [x, y+1], [x+1, y+1]].select do |n|
		in_image_bounds?(image, n[0], n[1])		
	end
end

def find_blob(my_view, image, blobs, x, y)
	blob = Blob.new
	stack = []
	stack << [x, y]

	while(!stack.empty?)
		next_pixel = stack.pop
		blob.add_point(*next_pixel)

		my_view[next_pixel[1]][next_pixel[0]].red = 0
		my_view[next_pixel[1]][next_pixel[0]].blue = quantumify(255)

		neighbours(image, *next_pixel).each do |xy|
			if my_view[xy[1]][xy[0]].red == quantumify(255)
				stack << [xy[0], xy[1]]
			end
		end
	end

	blobs << blob if blob.points.length > 15 && is_blob_rect?(blob)
end

old_filename = ""
newest_image_command = "ls shots/ -rt | tail -1"
filename = %x[#{newest_image_command}].inspect.gsub("\"", "")
filename.gsub!("\\n", "")

while 1
	while filename == old_filename
		newest_image_command = "ls shots/ -rt | tail -1"
		filename = %x[#{newest_image_command}].inspect.gsub("\"", "")
		filename.gsub!("\\n", "")
		puts "current file: " + filename
		sleep 1 
	end

	puts "loading new file: " + filename
	img_list = ImageList.new("shots/#{filename}")
	%x[`rm shots/shot*`]
	img_list.rotate!(180)
	blob_view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)
	orig_img_view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)

	blobs = []
	width = img_list.bounding_box.width-1
	height = img_list.bounding_box.height-1

	blob_view[][].map do |pixel|
		if (2 * pixel.red) - (pixel.green + pixel.blue) > quantumify(130)
			pixel.red = quantumify(255)
			pixel.green = pixel.blue = 0
		else
			pixel.red = pixel.green = pixel.blue = 0
		end
	end


#	blob_view.sync
#	img_list.display

	for cur_x in (0..width) do
		for cur_y in (0..height) do
			if blob_view[cur_y][cur_x].red == quantumify(255)
				find_blob(blob_view, img_list, blobs, cur_x, cur_y)
			end
		end
	end


	blobs.each do |b|
		b.points.each do |p|	
			orig_img_view[p[1]][p[0]].red = orig_img_view[p[1]][p[0]].blue = 0
			orig_img_view[p[1]][p[0]].green = quantumify(255)
		end
	end

	orig_img_view.sync
	img_list.write("output/#{filename}")

	old_filename = filename
end
