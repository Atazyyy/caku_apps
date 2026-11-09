import requests
import base64
from PIL import Image
from io import BytesIO

# Send request ke server
response = requests.post(
    'http://192.168.1.6:8000/predict',
    files={'file': open('./uploads/struk-indmrt.jpg', 'rb')}
)

data = response.json()

# Extract visualization (BASE64 string)
vis_base64_url = data['visualization']  # Format: "data:image/jpeg;base64,/9j/..."

# Pisahkan header dari data
vis_base64_only = vis_base64_url.split(',')[1]

# Decode dan buka di image viewer
img = Image.open(BytesIO(base64.b64decode(vis_base64_only)))
img.show()  # Buka secara otomatis

# Atau save ke file
img.save('detection_result.jpg')
print("✅ Tersimpan sebagai: detection_result.jpg")
