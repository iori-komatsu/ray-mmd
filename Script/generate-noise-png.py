from PIL import Image
import numpy as np

def main():
    noise = np.random.randint(low=0, high=256, size=(256, 256, 3), dtype=np.uint8)
    image = Image.fromarray(noise, mode="RGB")
    image.save("noise.png")

if __name__ == "__main__":
    main()
