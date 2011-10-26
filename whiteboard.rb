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
	#check the amount of pixels that don't 'fill' the square
#	puts blob.avg_x.to_s + ", " + blob.avg_y.to_s
	coverage = (blob.points.length.to_f / (width * height).to_f).to_f
	coverage >= 0.8 && coverage <= 1.5
end

def in_image_bounds?(image, x, y)
	x > 0 && x < image.columns && y > 0 && y < image.rows
end

def neighbours(image, x, y)
	[[x-1, y-1], [x, y-1], [x-1, y], [x+1, y-1], [x+1, y+1], [x+1, y], [x, y+1], [x+1, y+1]].select do |n|
		in_image_bounds?(image, n[0], n[1])		
	end
end

def find_blob(view, image, blobs, x, y)
	blob = Blob.new
	find_blobs_recursive(view, image, blob, x, y)
	blobs << blob if blob.points.length > 20 && is_blob_rect?(blob)
end

def find_blobs_recursive(my_view, image, blob, x, y)
	if in_image_bounds?(image, x, y) && my_view[y][x].red == quantumify(255)
		blob.add_point(x, y)

		#mark this as already added to blob by changing its colour
		my_view[y][x].red = my_view[y][x].green = 0
		my_view[y][x].blue = quantumify(255) 
		neighbours(image, x, y).map do |xy|
			find_blobs_recursive(my_view, image, blob, xy[0], xy[1]).inspect
		end
	end
	return nil
end

img_list = ImageList.new("test.png")

blob_view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)
orig_img_view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)

blobs = []
width = img_list.bounding_box.width-1
height = img_list.bounding_box.height-1

blob_view[][].map do |pixel|

	if (2 * pixel.red) - (pixel.green + pixel.blue) > quantumify(110)
		pixel.red = quantumify(255)
		pixel.green = pixel.blue = 0
	end
end

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
img_list.write("final-output.png")
#img_list.display
