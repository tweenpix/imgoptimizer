# imgoptimizer
Optimize images via Squoosh

- optimize jpg
- optimize png
- optimize svg
- convert bmp to jpg
- convert jpg,png to webp + avif
- check for avoid double optimization

# Requirements
for running need installed node.js + squoosh-cli + mogrify (ImageMagick) + svgo

# Running
run from parrent image directory
as
find . -type d \( ! -name . \) -exec bash -c "cd '{}' && pwd && /home/backup/imagecompress.sh" \;


Example
https://imgur.com/gallery/ytHTvaK
