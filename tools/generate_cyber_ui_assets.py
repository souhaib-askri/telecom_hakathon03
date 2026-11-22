import os
import math
from PIL import Image, ImageDraw, ImageFilter

out_dir = "/home/askri/Sproject/the-last-signal0.2/telecom_hakathon/assets/sprites/ui/cyber"
os.makedirs(out_dir, exist_ok=True)

def create_pip_health(full=True):
    size = (20, 20)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    # Diamond/angled tech capsule
    points = [(10, 2), (18, 6), (18, 14), (10, 18), (2, 14), (2, 6)]
    
    if full:
        # Glow
        draw.polygon(points, fill=(10, 50, 40, 220), outline=(0, 255, 170, 255))
        # Inner bright core
        inner = [(10, 5), (15, 8), (15, 12), (10, 15), (5, 12), (5, 8)]
        draw.polygon(inner, fill=(0, 255, 180, 255))
        # Highlight pip
        draw.line([(8, 7), (12, 7)], fill=(220, 255, 240, 255), width=1)
    else:
        draw.polygon(points, fill=(10, 20, 25, 140), outline=(0, 100, 90, 120))
        draw.line([(6, 10), (14, 10)], fill=(0, 80, 70, 100), width=1)
        
    return im

def create_pip_tower(full=True):
    size = (20, 20)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    # Shield/tower node shape
    points = [(4, 3), (16, 3), (18, 10), (10, 18), (2, 10)]
    
    if full:
        draw.polygon(points, fill=(8, 35, 65, 230), outline=(0, 180, 255, 255))
        inner = [(6, 5), (14, 5), (15, 10), (10, 15), (5, 10)]
        draw.polygon(inner, fill=(0, 210, 255, 255))
        draw.line([(8, 7), (12, 7)], fill=(220, 250, 255, 255), width=1)
    else:
        draw.polygon(points, fill=(8, 18, 30, 140), outline=(0, 80, 130, 120))
        draw.line([(6, 8), (14, 8)], fill=(0, 60, 100, 100), width=1)
        
    return im

def create_slot(active=False):
    size = (48, 48)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    # Background rounded rect
    bg_color = (12, 28, 45, 235) if active else (6, 14, 24, 210)
    border_color = (0, 230, 255, 255) if active else (0, 130, 180, 160)
    
    draw.rounded_rectangle([(1, 1), (46, 46)], radius=4, fill=bg_color, outline=border_color, width=2 if active else 1)
    
    # Tech corner notches
    c_len = 5
    accent = (0, 255, 255, 255) if active else (0, 180, 230, 200)
    # top-left
    draw.line([(1, 1), (1 + c_len, 1)], fill=accent, width=2)
    draw.line([(1, 1), (1, 1 + c_len)], fill=accent, width=2)
    # top-right
    draw.line([(46 - c_len, 1), (46, 1)], fill=accent, width=2)
    draw.line([(46, 1), (46, 1 + c_len)], fill=accent, width=2)
    # bottom-left
    draw.line([(1, 46 - c_len), (1, 46)], fill=accent, width=2)
    draw.line([(1, 46), (1 + c_len, 46)], fill=accent, width=2)
    # bottom-right
    draw.line([(46 - c_len, 46), (46, 46)], fill=accent, width=2)
    draw.line([(46, 46 - c_len), (46, 46)], fill=accent, width=2)
    
    if active:
        # Inner subtle glow outline
        draw.rounded_rectangle([(3, 3), (44, 44)], radius=3, outline=(0, 230, 255, 100), width=1)
        
    return im

def create_btn_action(pressed=False, is_red=False):
    size = (52, 52)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    if is_red:
        bg = (180, 40, 50, 240) if pressed else (120, 25, 35, 220)
        border = (255, 90, 100, 255) if pressed else (240, 50, 60, 220)
        glow = (255, 140, 150, 180)
    else:
        bg = (0, 110, 160, 240) if pressed else (8, 30, 50, 220)
        border = (0, 230, 255, 255) if pressed else (0, 160, 220, 200)
        glow = (180, 245, 255, 180)
        
    draw.rounded_rectangle([(2, 2), (49, 49)], radius=6, fill=bg, outline=border, width=2)
    draw.line([(6, 5), (45, 5)], fill=glow, width=1)
    return im

def create_dpad_ring():
    size = (120, 120)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    # Outer circle
    draw.ellipse([(4, 4), (115, 115)], fill=(6, 16, 26, 120), outline=(0, 180, 240, 180), width=2)
    # Middle dashed/concentric ring
    draw.ellipse([(20, 20), (99, 99)], outline=(0, 140, 200, 80), width=1)
    # Inner ring
    draw.ellipse([(44, 44), (75, 75)], outline=(0, 200, 255, 100), width=1)
    
    # Crosshair ticks
    draw.line([(60, 8), (60, 24)], fill=(0, 230, 255, 200), width=2)
    draw.line([(60, 96), (60, 112)], fill=(0, 230, 255, 200), width=2)
    draw.line([(8, 60), (24, 60)], fill=(0, 230, 255, 200), width=2)
    draw.line([(96, 60), (112, 60)], fill=(0, 230, 255, 200), width=2)
    return im

def create_dpad_knob():
    size = (54, 54)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    draw.ellipse([(2, 2), (51, 51)], fill=(10, 40, 65, 230), outline=(0, 230, 255, 255), width=2)
    draw.ellipse([(14, 14), (39, 39)], fill=(0, 180, 235, 220), outline=(200, 250, 255, 255), width=1)
    draw.ellipse([(23, 23), (30, 30)], fill=(255, 255, 255, 255))
    return im

def create_arrow(dir="up"):
    size = (36, 36)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    # Sleek cyber chevron
    if dir == "up":
        pts = [(18, 8), (28, 22), (24, 25), (18, 17), (12, 25), (8, 22)]
    elif dir == "down":
        pts = [(18, 28), (28, 14), (24, 11), (18, 19), (12, 11), (8, 14)]
    elif dir == "left":
        pts = [(8, 18), (22, 8), (25, 12), (17, 18), (25, 24), (22, 28)]
    else: # right
        pts = [(28, 18), (14, 8), (11, 12), (19, 18), (11, 24), (14, 28)]
        
    draw.polygon(pts, fill=(0, 220, 255, 240), outline=(200, 250, 255, 255))
    return im

# Generate all assets
create_pip_health(True).save(os.path.join(out_dir, "cyber_pip_health_full.png"))
create_pip_health(False).save(os.path.join(out_dir, "cyber_pip_health_empty.png"))
create_pip_tower(True).save(os.path.join(out_dir, "cyber_pip_tower_full.png"))
create_pip_tower(False).save(os.path.join(out_dir, "cyber_pip_tower_empty.png"))

create_slot(False).save(os.path.join(out_dir, "cyber_slot_normal.png"))
create_slot(True).save(os.path.join(out_dir, "cyber_slot_active.png"))

create_btn_action(False, False).save(os.path.join(out_dir, "cyber_btn_normal.png"))
create_btn_action(True, False).save(os.path.join(out_dir, "cyber_btn_pressed.png"))
create_btn_action(False, True).save(os.path.join(out_dir, "cyber_btn_fire.png"))
create_btn_action(True, True).save(os.path.join(out_dir, "cyber_btn_fire_pressed.png"))

create_dpad_ring().save(os.path.join(out_dir, "cyber_dpad_ring.png"))
create_dpad_knob().save(os.path.join(out_dir, "cyber_dpad_knob.png"))

create_arrow("up").save(os.path.join(out_dir, "cyber_arrow_up.png"))
create_arrow("down").save(os.path.join(out_dir, "cyber_arrow_down.png"))
create_arrow("left").save(os.path.join(out_dir, "cyber_arrow_left.png"))
create_arrow("right").save(os.path.join(out_dir, "cyber_arrow_right.png"))

# Also tactical vector icons
def create_icon_weapon():
    size = (32, 32)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    # Futuristic Blaster silhouette
    draw.polygon([(6, 14), (20, 14), (20, 11), (25, 11), (25, 17), (20, 17), (17, 24), (13, 24), (15, 18), (6, 18)], fill=(0, 230, 255, 255))
    draw.line([(24, 14), (28, 14)], fill=(255, 230, 80, 255), width=2)
    return im

def create_icon_surge():
    size = (32, 32)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    # Double chevron / burst
    draw.polygon([(16, 5), (25, 15), (21, 17), (16, 11), (11, 17), (7, 15)], fill=(0, 255, 200, 255))
    draw.polygon([(16, 14), (25, 24), (21, 26), (16, 20), (11, 26), (7, 24)], fill=(0, 210, 255, 255))
    return im

def create_icon_wall():
    size = (32, 32)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    # Energy barrier hex shield
    draw.polygon([(16, 4), (26, 9), (26, 21), (16, 27), (6, 21), (6, 9)], fill=(20, 60, 40, 200), outline=(0, 255, 150, 255), width=2)
    draw.line([(16, 8), (16, 23)], fill=(0, 255, 150, 255), width=1)
    draw.line([(9, 15), (23, 15)], fill=(0, 255, 150, 255), width=1)
    return im

def create_icon_turret():
    size = (32, 32)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    # Radar / turret sentinel
    draw.ellipse([(10, 8), (22, 20)], fill=(30, 50, 80, 220), outline=(0, 200, 255, 255), width=2)
    draw.polygon([(13, 20), (19, 20), (23, 27), (9, 27)], fill=(0, 160, 220, 255))
    draw.line([(16, 8), (26, 4)], fill=(255, 90, 90, 255), width=2)
    return im

def create_icon_dots():
    size = (32, 32)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    for x in [8, 16, 24]:
        draw.ellipse([(x - 2, 14), (x + 2, 18)], fill=(0, 220, 255, 255))
    return im

create_icon_weapon().save(os.path.join(out_dir, "cyber_icon_weapon.png"))
create_icon_surge().save(os.path.join(out_dir, "cyber_icon_surge.png"))
create_icon_wall().save(os.path.join(out_dir, "cyber_icon_wall.png"))
create_icon_turret().save(os.path.join(out_dir, "cyber_icon_turret.png"))
create_icon_dots().save(os.path.join(out_dir, "cyber_icon_dots.png"))

print("All cyber UI assets created successfully in", out_dir)
