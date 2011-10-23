require 'RMagick'
include Magick

def quantumify(number)
	(number.to_f / 255.0) * Magick::QuantumRange
end

class Blob
	@min_x = 0
	@max_x = 0

	@min_y = 0
	@max_y = 0
end

#img = Image.new(200,200) { self.background_color = Pixel.new(quantumify(214), quantumify(124), quantumify(124)) }
#view = Image::View.new(img, 0, 0, 200, 200);
imgList = ImageList.new("webcam-capture.png")

blobs = []

#targetPixel = Pixel.new(195,102,116);
#targetPixel = Pixel.new(214, 124, 124);
target_pixel = Pixel.new(quantumify(249), quantumify(145), quantumify(138))
new_pixel = Pixel.new(0,0,0,1)

imgList = imgList.edge(8)
view = Image::View.new(imgList, 0, 0, imgList.bounding_box.width, imgList.bounding_box.height)

view.sync
imgList.display
imgList.write("after_edge_detection.png")

view[][].each do |pixel|
	#eliminate all not perfect reds
	if !(pixel.red == quantumify(255) && pixel.green == 0 && pixel.blue == 0)
		pixel.red = pixel.green = pixel.blue = 0; 
	end
end

view.sync
imgList.write("after_colour_correction.png")

new_view = Image::View.new(imgList, 0, 0, imgList.bounding_box.width, imgList.bounding_box.height)

for cur_x in (0..imgList.bounding_box.width-1) do
	for cur_y in (0..imgList.bounding_box.height-1) do

		if view[cur_y][cur_x].red == 0
			next
		end

		min_x = cur_x - 1 > 0 ? cur_x - 1: 0
		max_x = cur_x + 1 < imgList.bounding_box.width - 1 ? cur_x + 1 : imgList.bounding_box.width - 1

		min_y = cur_y - 1 > 0 ? cur_y - 1: 0
		max_y = cur_y + 1 < imgList.bounding_box.height- 1 ? cur_y + 1 : imgList.bounding_box.height - 1

		if (view[min_y][min_x].red == 0 || view[min_y][max_x].red == 0 || view[max_y][min_x].red == 0 || view[max_y][max_x].red == 0 ||
			view[cur_y][min_x].red == 0 || view[cur_y][max_x].red == 0 || view[min_y][cur_x].red == 0 || view[max_y][cur_x].red == 0)
			new_view[cur_y][cur_x].red = 0
		end
	end
end
new_view.sync
imgList.display
imgList.write("final_output.png")

