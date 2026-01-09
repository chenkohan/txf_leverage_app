from PIL import Image, ImageDraw, ImageFont
import os

# 圖示尺寸對應
sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

base_path = r'D:\Dropbox\FlutterProjects\txf_leverage_app\android\app\src\main\res'

def create_icon(size, output_path):
    # 建立圖片（紅色圓圈背景）
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 畫紅色圓圈
    padding = 0
    draw.ellipse([padding, padding, size - padding, size - padding], fill='#E53935')
    
    # 嘗試使用粗體字型
    font_size = int(size * 0.27)  # 調整字體大小比例
    try:
        # Windows 粗體字型
        font = ImageFont.truetype("arialbd.ttf", font_size)
    except:
        try:
            font = ImageFont.truetype("Arial Bold.ttf", font_size)
        except:
            try:
                font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", font_size)
            except:
                font = ImageFont.load_default()
    
    # 寫文字 TXFL（暗綠色）
    text = "TXFL"
    text_color = '#1B5E20'  # 暗綠色
    
    # 取得文字邊界框來置中
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (size - text_width) / 2
    y = (size - text_height) / 2 - bbox[1]  # 調整垂直置中
    
    draw.text((x, y), text, fill=text_color, font=font)
    
    # 儲存
    img.save(output_path, 'PNG')
    print(f'Created: {output_path}')

# 產生各尺寸圖示
for folder, size in sizes.items():
    output_path = os.path.join(base_path, folder, 'ic_launcher.png')
    create_icon(size, output_path)

print('All icons generated!')
