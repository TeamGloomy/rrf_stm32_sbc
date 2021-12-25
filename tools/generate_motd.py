# -*- coding: utf-8 -*-

# This script is used to generate the logo displayed on the motd header

from PIL import Image

# Color escape codes
BG_RESET = "\x1b[0m"
BG_BLACK = "\x1b[40m"
BG_RGB = "\x1b[38;2;"


def resize_to_width(img: Image,
                    width: int,
                    aspect_ratio: float=0.5) -> Image:
    wpercent = (width / float(img.size[0])) * aspect_ratio
    hsize = int((float(img.size[1]) * float(wpercent)))
    return img.resize((width, hsize), Image.ANTIALIAS)


def convert(img: Image) -> str:
    txt = ""
    img = resize_to_width(img, 40)
    for y in range(img.height):
        # padding to center horizontaly the motd pattern
        txt += f"{BG_BLACK}{''.rjust(10, ' ')}"
        for x in range(img.width):
            red, green, blue = img.getpixel((x,y))
            char = "#"
            txt += f"{BG_RGB}{red};{green};{blue}m{char}"
        txt += "\n"
    txt += BG_RESET
    return txt

print(convert(Image.open("assets/company_logo.png")))
