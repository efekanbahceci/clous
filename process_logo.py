from PIL import Image
import math

# Load the image
img = Image.open("/Users/efekan/.gemini/antigravity/brain/1909d7c1-427d-4ba2-923f-f55116bbf3e3/.user_uploaded/media_1790708849910.png").convert("RGBA")
datas = img.getdata()

newData = []
for item in datas:
    # item is (R, G, B, A)
    # The red color is roughly (150-170, 30-50, 30-50)
    # White is (255, 255, 255)
    # We can use the Green channel as a base for alpha since it separates red (low) from white (high)
    g = item[1]
    
    # Thresholding for anti-aliasing
    if g > 200:
        newData.append((255, 255, 255, 255))
    elif g < 100:
        newData.append((255, 255, 255, 0))
    else:
        # Smooth transition for anti-aliasing
        alpha = int((g - 100) / 100 * 255)
        newData.append((255, 255, 255, alpha))

img.putdata(newData)
img.save("apps/web/public/logo.png", "PNG")
print("Logo saved successfully.")
