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

def is_blob_square?(blob)
	left = blob.min_x
	right = blob.max_x
	top = blob.min_y
	bottom = blob.max_y
	
	width = right - left
	height = bottom - top

	#a square placed on top of the blob
	#check the amount of pixels that don't 'fill' the square
	puts blob.points.length.to_s + ", " + (width * height).to_s
	(blob.points.length.to_f / (width * height).to_f).to_f >= 0.9
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
	blobs << blob if blob.points.length > 30 && is_blob_square?(blob)
end

def find_blobs_recursive(my_view, image, blob, x, y)
	if in_image_bounds?(image, x, y) && my_view[y][x].red == quantumify(255)
		#puts "adding a point: " + x.to_s + ", " + y.to_s
		blob.add_point(x, y)
		#puts blob.inspect	

		#mark this as already added to blob by changing its colour
		my_view[y][x].red = my_view[y][x].green = 0
		my_view[y][x].blue = quantumify(255) 
		neighbours(image, x, y).map do |xy|
			find_blobs_recursive(my_view, image, blob, xy[0], xy[1]).inspect
		end
	end
	return nil
end


#img = Image.new(200,200) { self.background_color = Pixel.new(quantumify(214), quantumify(124), quantumify(124)) }
#view = Image::View.new(img, 0, 0, 200, 200);
#img_list = ImageList.new("webcam-capture.bmp")
img_list = ImageList.new("webcam-capture.jpeg")

#targetPixel = Pixel.new(195,102,116);
#targetPixel = Pixel.new(214, 124, 124);
target_pixel = Pixel.new(quantumify(249), quantumify(145), quantumify(138))


#img_list.display

#img_list = img_list.edge(20)
view = Image::View.new(img_list, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)

#view.sync
#img_list.display
#img_list.write("after_edge_detection.png")

#view[][].each do |pixel|
	#eliminate all not perfect reds
#	if !(pixel.red == quantumify(255) && pixel.green == 0 && pixel.blue == 0)
#		pixel.red = pixel.green = pixel.blue = 0; 
#	end
#end

#view.sync
#img_list.write("after_colour_correction.png")

blank_img = Image.new(img_list.cur_image.columns, img_list.cur_image.rows) { self.background_color = "black" }
new_view = Image::View.new(blank_img, 0, 0, img_list.cur_image.columns, img_list.cur_image.rows)

blobs = []
width = img_list.bounding_box.width-1
height = img_list.bounding_box.height-1

for cur_x in (0..width) do
	for cur_y in (0..height) do

		#if view[cur_y][cur_x].red == 0
		#	next
		#end

		if (2 * view[cur_y][cur_x].red) - (view[cur_y][cur_x].green + view[cur_y][cur_x].blue) > quantumify(80)
			new_view[cur_y][cur_x].red = quantumify(255)
			new_view[cur_y][cur_x].green = new_view[cur_y][cur_x].blue = 0
			#find_blob(new_view, img_list, blobs, cur_x, cur_y)
		end
=begin
		min_x = cur_x - 1 > 0 ? cur_x - 1: 0
		max_x = cur_x + 1 < img_list.bounding_box.width - 1 ? cur_x + 1 : img_list.bounding_box.width - 1

		min_y = cur_y - 1 > 0 ? cur_y - 1: 0
		max_y = cur_y + 1 < img_list.bounding_box.height- 1 ? cur_y + 1 : img_list.bounding_box.height - 1
=end
#		if (view[min_y][min_x].red == 0 || view[min_y][max_x].red == 0 || view[max_y][min_x].red == 0 || view[max_y][max_x].red == 0 ||
#			view[cur_y][min_x].red == 0 || view[cur_y][max_x].red == 0 || view[min_y][cur_x].red == 0 || view[max_y][cur_x].red == 0)
#			new_view[cur_y][cur_x].red = 0

		#neighbours(img_list, cur_x, cur_y).map do |xy|
	#		if view[xy[1]][xy[0]].red == 0
#				new_view[cur_y][cur_x].red = 0
#				break
#			end
#		end
	end
end

for cur_x in (0..width) do
	for cur_y in (0..height) do
		if new_view[cur_y][cur_x].red == quantumify(255)
			find_blob(new_view, img_list, blobs, cur_x, cur_y)
		end
	end
end


blobs.each do |b|
	b.points.each do |p|	
		new_view[p[1]][p[0]].red = new_view[p[1]][p[0]].blue = 0
		new_view[p[1]][p[0]].green = quantumify(255)
	end
end

new_view.sync
#blank_img.display
blank_img.write("final-output.png")
#img_list.display
#ist https://gist.github.com/947709mg_list.write("final_output.png")
