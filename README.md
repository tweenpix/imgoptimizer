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


# Installation
First of first, need install NODE.JS 16x    

## 1. Node.js for Ubuntu    
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -    
sudo apt-get install -y nodejs    

## 1. Node.js for Debian, as root    
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -    
apt-get install -y nodejs    

## 2. Install squoosh/cli    
npm i -g @squoosh/cli    

## 3. Make link to USR/LOCAL/BIN
chmod +x /path/to/imagecompress.sh    
ln -s /path/to/imagecompress.sh /usr/local/bin/imagecompress



# Running
run from parrent image directory for recursivly optimization    
as    
find . -type d \( ! -name . \) -exec bash -c "cd '{}' && imagecompress" \;


## Example
# ![https://imgur.com/gallery/ytHTvaK](https://i.imgur.com/P7yF4uc.png)
