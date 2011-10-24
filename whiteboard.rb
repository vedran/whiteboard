require 'RMagick'
include Magick

class Blob

	attr_reader :points

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

		@max_x = x if @max_x.nil? || x < @max_x
		@max_y = y if @max_y.nil? || y < @max_y

		@points << [x, y]
		@avg_x = ((@avg_x * (@points.length-1)) + x) / (@points.length)
		@avg_y = ((@avg_y * (@points.length-1)) + y) / (@points.length)
	end

end

def quantumify(number)
	(number.to_f / 255.0) * Magick::QuantumRange
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
	puts "start call"
	find_blobs_recursive(view, image, blob, x, y)
	blobs << blob if blob.points.length > 10
end

def find_blobs_recursive(view, image, blob, x, y)
	if in_image_bounds?(image, x, y) && view[y][x].red == quantumify(255)
		puts "adding a point: " + x.to_s + ", " + y.to_s
		blob.add_point(x, y)
		
		#mark this as already added to blob by changing its colour
		view[y][x].red = 0
		view[y][x].blue = quantumify(255) 
		puts "check " + neighbours(image, x, y).inspect
		neighbours(image, x, y).map do |xy|
			puts "start inner recursive call"
			find_blobs_recursive(view, image, blob, xy[1], xy[0])
			puts "finish inner recursive call"
		end
	end
end


#img = Image.new(200,200) { self.background_color = Pixel.new(quantumify(214), quantumify(124), quantumify(124)) }
#view = Image::View.new(img, 0, 0, 200, 200);
#img_list = ImageList.new("webcam-capture.bmp")
img_list = ImageList.new("test.png")

#targetPixel = Pixel.new(195,102,116);
#targetPixel = Pixel.new(214, 124, 124);
target_pixel = Pixel.new(quantumify(249), quantumify(145), quantumify(138))

#img_list = img_list.edge(20)
view = Image::View.new(img_list, 0, 0, img_list.cur_image.rows, img_list.cur_image.columns)

view.sync
#img_list.display
img_list.write("after_edge_detection.png")

view[][].each do |pixel|
	#eliminate all not perfect reds
	if !(pixel.red == quantumify(255) && pixel.green == 0 && pixel.blue == 0)
		pixel.red = pixel.green = pixel.blue = 0; 
	end
end

view.sync
img_list.write("after_colour_correction.png")

new_view = Image::View.new(img_list, 0, 0, img_list.cur_image.rows, img_list.cur_image.columns)

blobs = []

for cur_x in (0..img_list.bounding_box.width-1) do
	for cur_y in (0..img_list.bounding_box.height-1) do

		if view[cur_y][cur_x].red == 0
			next
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

		neighbours(img_list, cur_x, cur_y).map do |xy|
			if view[xy[1]][xy[0]].red == 0
				new_view[cur_y][cur_x].red = 0
				break
			end
		end
	end
end


for cur_x in (0..img_list.bounding_box.width-1) do
	for cur_y in (0..img_list.bounding_box.height-1) do
		if view[cur_y][cur_x].red == quantumify(255)
			find_blob(new_view, img_list, blobs, cur_x, cur_y)
		end
	end
end

puts blobs.length

new_view.sync
img_list.display
img_list.write("final_output.png")
